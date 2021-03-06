require "../src/quartz"

class TrafficLight < Quartz::AtomicModel
  input interrupt
  output observed

  state do
    var phase : Symbol = :red
  end

  def external_transition(bag)
    value = bag[input_port(:interrupt)].first.as_sym
    case value
    when :to_manual
      self.phase = :manual if {:red, :green, :orange}.includes?(phase)
    else # :to_autonomous
      self.phase = :red if phase == :manual
    end
  end

  def internal_transition
    self.phase = case phase
                 when :red    then :green
                 when :green  then :orange
                 when :orange then :red
                 else              phase
                 end
  end

  def output
    observed = case phase
               when :red, :orange then :grey
               when :green        then :orange
               else                    raise "BUG: unreachable"
               end
    post observed, on: :observed
  end

  def time_advance : Quartz::Duration
    case phase
    when :red    then Quartz.duration(60)
    when :green  then Quartz.duration(50)
    when :orange then Quartz.duration(10)
    else              Quartz::Duration::INFINITY
    end
  end
end

class Policeman < Quartz::AtomicModel
  output traffic_light

  state do
    var phase : Symbol = :idle
  end

  def internal_transition
    self.phase = case phase
                 when :idle then :working
                 else            :idle
                 end
  end

  def output
    mode = case phase
           when :idle    then :to_manual
           when :working then :to_autonomous
           else               raise "BUG: unreachable"
           end
    post mode, on: :traffic_light
  end

  def time_advance : Quartz::Duration
    phase == :idle ? Quartz.duration(200) : Quartz.duration(100)
  end

  def external_transition(bag)
  end
end

class PortObserver
  include Quartz::Observer

  def initialize(port : Quartz::OutputPort)
    port.add_observer(self)
  end

  def update(observable, info)
    if observable.is_a?(Quartz::OutputPort) && info
      payload = info[:payload]
      time = info[:time].as(Quartz::TimePoint)
      puts "#{observable.host}@#{observable} sends '#{payload}' at #{time.to_s}"
    end
  end
end

coupled = Quartz::CoupledModel.new(:crossroad)
coupled << TrafficLight.new(:traffic_light)
coupled << Policeman.new(:policeman)
coupled.attach :traffic_light, to: :interrupt, between: :policeman, and: :traffic_light
PortObserver.new(coupled[:traffic_light].output_port(:observed))

simulation = Quartz::Simulation.new(coupled, duration: Quartz.duration(1000), scheduler: :binary_heap)
Quartz.set_debug_log_level
simulation.simulate
