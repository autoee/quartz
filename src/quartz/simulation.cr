module Quartz
  # This class represent the interface to the simulation
  class Simulation
    include Logging
    include Enumerable(TimePoint)
    include Iterable(TimePoint)

    # Represents the current simulation status.
    enum Status
      Ready,
      Initialized,
      Running,
      Done,
      Aborted
    end

    getter processor, model, start_time, final_time, vtime
    getter status : Status

    @status : Status
    @vtime : TimePoint
    @final_vtime : TimePoint
    @scheduler : Symbol
    @processor : Simulable?
    @start_time : Time?
    @final_time : Time?
    @run_validations : Bool
    @model : CoupledModel

    delegate ready?, to: @status
    delegate initialized?, to: @status
    delegate running?, to: @status
    delegate done?, to: @status
    delegate aborted?, to: @status

    def initialize(model : Model, *,
                   scheduler : Symbol = :calendar_queue,
                   maintain_hierarchy : Bool = true,
                   duration : Duration = Duration::INFINITY,
                   run_validations : Bool = false)
      @vtime = TimePoint.new(0)
      @final_vtime = TimePoint.new(duration.multiplier, duration.precision)

      @model = case model
               when AtomicModel, MultiComponent::Model
                 CoupledModel.new(:root_coupled_model) << model
               else
                 model
               end

      @scheduler = scheduler
      @run_validations = run_validations
      @status = Status::Ready

      unless maintain_hierarchy
        Quartz.timing("Modeling tree flattening") {
          @model.accept(DirectConnectionVisitor.new(@model))
        }
      end
    end

    @[AlwaysInline]
    protected def processor
      @processor ||= begin
        Quartz.timing("Processor allocation") do
          visitor = ProcessorAllocator.new(self, @model)
          model.accept(visitor)
          visitor.simulable
        end
      end
    end

    def inspect(io)
      io << "<" << self.class.name << ": status=" << status.to_s(io)
      io << ", time=" << @vtime.to_s(io)
      io << ", final_time=" << @final_vtime.to_s(io)
      nil
    end

    # Returns the default scheduler to use.
    def default_scheduler
      @scheduler
    end

    # Whether `Quartz::Validations` will be run during simulation.
    def run_validations?
      @run_validations
    end

    def percentage
      case @status
      when Status::Ready, Status::Initialized
        0.0 * 100
      when Status::Done
        1.0 * 100
      when Status::Running, Status::Aborted
        if @vtime > @final_vtime
          1.0 * 100
        else
          (@vtime.to_i64 - @final_vtime) / (Duration.new(@final_vtime.to_i64, @final_vtime.precision)) * 100
        end
      end
    end

    def elapsed_secs
      case @status
      when Status::Ready, Status::Initialized
        0.0
      when Status::Done, Status::Aborted
        @final_time.not_nil! - @start_time.not_nil!
      when Status::Running
        Time.now - @start_time.not_nil!
      end
    end

    # Returns the number of transitions per model along with the total
    def transition_stats
      stats = {} of Name => Hash(Symbol, UInt32)
      hierarchy = self.processor.children.dup
      hierarchy.each do |child|
        if child.is_a?(Coordinator)
          coordinator = child.as(Coordinator)
          hierarchy.concat(coordinator.children)
        else
          simulator = child.as(Simulator)
          stats[child.model.name] = simulator.transition_stats.to_h
        end
      end
      total = Hash(Symbol, UInt32).new { 0_u32 }
      stats.values.each { |h| h.each { |k, v| total[k] += v } }
      stats[:TOTAL] = total
      stats
    end

    # Abort the currently running or initialized simulation. Goes to an
    # aborted state.
    def abort
      if running? || initialized?
        Hooks.notifier.notify(Hooks::PRE_ABORT)
        info "Aborting simulation."
        @final_time = Time.now
        @status = Status::Aborted
        Hooks.notifier.notify(Hooks::POST_ABORT)
      end
    end

    # Restart a terminated simulation (either done or aborted) and goes to a
    # ready state.
    def restart
      case @status
      when Status::Done, Status::Aborted
        Hooks.notifier.notify(Hooks::PRE_RESTART)
        @vtime = TimePoint.new(0)
        @start_time = nil
        @final_time = nil
        @status = Status::Ready
        Hooks.notifier.notify(Hooks::POST_RESTART)
      when Status::Running, Status::Initialized
        info "Cannot restart, the simulation is currently running."
      end
    end

    private def begin_simulation
      @start_time = Time.now
      @status = Status::Running
      info "Beginning simulation until time point: #{@final_vtime}"
      Hooks.notifier.notify(Hooks::PRE_SIMULATION)
    end

    private def end_simulation
      @final_time = Time.now
      @status = Status::Done

      if logger = Quartz.logger?
        logger.info "Simulation ended after #{elapsed_secs} secs."
        if logger.debug?
          str = String.build(512) do |str|
            str << "Transition stats : {\n"
            transition_stats.each do |k, v|
              str << "    #{k} => #{v}\n"
            end
            str << "}\n"
          end
          logger.debug str
          logger.debug "Running post simulation hook"
        end
      end
      Hooks.notifier.notify(Hooks::POST_SIMULATION)
    end

    def initialize_simulation
      if ready?
        begin_simulation
        Hooks.notifier.notify(Hooks::PRE_INIT)
        Quartz.timing("Simulation initialization") do
          duration = processor.initialize_state(@vtime)
          @vtime = @vtime.advance(duration)
        end
        @status = Status::Initialized
        Hooks.notifier.notify(Hooks::POST_INIT)
      else
        info "Cannot initialize simulation while it is running or terminated."
      end
    end

    def step : TimePoint?
      case @status
      when Status::Ready
        initialize_simulation
        @vtime
      when Status::Initialized, Status::Running
        if (logger = Quartz.logger?) && logger.debug?
          logger.debug("Tick at #{@vtime}, #{Time.now - @start_time.not_nil!} secs elapsed.")
        end
        duration = processor.step(@vtime)
        @vtime = @vtime.advance(duration)
        end_simulation if @vtime >= @final_vtime
        @vtime
      else
        nil
      end
    end

    # TODO error hook
    def simulate
      case @status
      when Status::Ready, Status::Initialized
        initialize_simulation unless initialized?

        begin_simulation
        while @vtime < @final_vtime
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug("Tick at: #{@vtime}, #{Time.now - @start_time.not_nil!} secs elapsed.")
          end
          duration = processor.step(@vtime)
          @vtime = @vtime.advance(duration)
        end
        end_simulation
      when Status::Running
        error "Simulation already started at #{@start_time} and is currently running."
      when Status::Done, Status::Aborted
        error "Simulation is terminated."
      end
      self
    end

    def each
      StepIterator.new(self)
    end

    def each
      case @status
      when Status::Ready, Status::Initialized
        initialize_simulation unless initialized?

        begin_simulation
        while @vtime < @final_vtime
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug("Tick at: #{@vtime}, #{Time.now - @start_time.not_nil!} secs elapsed.")
          end
          duration = processor.step(@vtime)
          @vtime = @vtime.advance(duration)
          yield(self)
        end
        end_simulation
      when Status::Running
        error "Simulation already started at #{@start_time} and is currently running."
      when Status::Done, Status::Aborted
        error "Simulation is terminated."
      end
      self
    end

    class StepIterator
      include Iterator(TimePoint)

      def initialize(@simulation : Simulation)
      end

      def next
        case @simulation.status
        when Simulation::Status::Done, Simulation::Status::Aborted
          stop
        when Simulation::Status::Ready
          @simulation.initialize_simulation
        when Simulation::Status::Initialized, Simulation::Status::Running
          @simulation.step.not_nil!
        end
      end

      def rewind
        @simulation.abort if @simulation.running?
        @simulation.restart
        self
      end
    end

    def generate_graph(path = "model_hierarchy.dot")
      path = "#{path}.dot" if File.extname(path).empty?
      file = File.new(path, "w+")
      generate_graph(file)
      file.close
    end

    def generate_graph(io : IO)
      DotVisitor.new(@model, io).to_graph
    end
  end
end
