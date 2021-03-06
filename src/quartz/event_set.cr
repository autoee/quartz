module Quartz
  # The `Schedulable` module is used as an interface for data types that may
  # be scheduled within an `EventSet`.
  module Schedulable
    # The planned phase, or the offset from the current epoch of the
    # event set, associated with the event.
    property planned_phase : Duration = Duration::INFINITY.fixed
    # The original precision level at which the event was originally planned.
    property planned_precision : Scale = Scale::BASE
    # The imaginary planned phase used to track elapsed times.
    property imaginary_phase : Duration = Duration::INFINITY.fixed
    # The original precision level at which the imaginary event was originally
    # planned.
    property imaginary_precision : Scale = Scale::BASE

    def inspect(io)
      super(io)

      io << " planned_phase="
      self.planned_phase.to_s(io)
      io << " imag_phase="
      self.imaginary_phase.to_s(io)
      io << ">"
    end
  end

  # A `PriorityQueue` is the base class to implement a planning strategy for all
  # future events to be evaluated. Events should be dequeued in a strict order
  # of precedence, according to their associated priority.
  #
  # The priority is represented by the `Duration` data type, which represent a
  # planned phase, an offset from the beginning of the current epoch relative
  # to the current simulated time.
  #
  # It is internally used by the pending event set `EventSet`.
  abstract class PriorityQueue(T)
    {% begin %}
    def self.new(priority_queue : Symbol, &comparator : Duration, Duration, Bool -> Int32) : self

      case priority_queue
      {% if flag?(:experimental) %}
      when :ladder_queue   then LadderQueue(T).new(&comparator)
      when :calendar_queue then CalendarQueue(T).new(&comparator)
      {% end %}
      when :binary_heap    then BinaryHeap(T).new(&comparator)
      when :fibonacci_heap then FibonacciHeap(T).new(&comparator)
      when :heap_set       then HeapSet(T).new(&comparator)
      else
        puts "Unknown priority queue '#{priority_queue}', defaults to binary heap"
        BinaryHeap(T).new(&comparator)
      end
    end
    {% end %}

    abstract def initialize(&comparator : Duration, Duration, Bool -> Int32)
    abstract def size : Int
    abstract def empty? : Bool
    abstract def clear
    abstract def push(priority : Duration, value : T)
    abstract def peek : T
    abstract def peek? : T?
    abstract def pop : T
    abstract def delete(priority : Duration, value : T) : T?
    abstract def next_priority : Duration

    def pop_imminents
      priority = self.next_priority
      while !empty? && self.next_priority == priority
        yield pop
      end
    end
  end

  # `EventSet` represents the pending event set and encompasses all future
  # events scheduled to occur.
  class EventSet
    # Returns the current time associated with the event set.
    property current_time : TimePoint

    getter priority_queue : PriorityQueue(Schedulable)

    def self.new(time : TimePoint = TimePoint.new(0)) : self
      new(:binary_heap, time)
    end

    def initialize(priority_queue : Symbol, @current_time : TimePoint = TimePoint.new(0))
      @priority_queue = PriorityQueue(Schedulable).new(priority_queue) { |a, b, b_in_current_epoch|
        cmp_planned_phases(a, b, b_in_current_epoch)
      }
    end

    # Returns the number of scheduled events.
    def size
      @priority_queue.size
    end

    # Whether the event set is empty.
    def empty? : Bool
      @priority_queue.empty?
    end

    # Clears `self`.
    def clear
      @current_time = TimePoint.new
      @priority_queue.clear
    end

    # Advance the current time up to the next planned event.
    def advance : TimePoint
      duration = imminent_duration
      if duration.infinite?
        @current_time
      else
        @current_time.advance(duration)
      end
    end

    # Advance the current time up to the specified planned duration using
    # a multiscale time advancement.
    #
    # Raises if the current time advances beyond the imminent events.
    def advance(by duration : Duration) : TimePoint
      if duration > imminent_duration
        raise BadSynchronisationError.new("Current time (#{@current_time}) cannot advance beyond imminent events (#{duration} > #{imminent_duration})")
      end
      @current_time.advance by: duration
    end

    # Advance the current time until it reaches the given time point.
    def advance(until t : TimePoint) : TimePoint
      while @current_time != t
        advance by: t.gap(@current_time)
      end
      @current_time
    end

    # Cancel the specified event.
    def cancel_event(event : Schedulable) : Schedulable?
      @priority_queue.delete(event.planned_phase, event).as(Schedulable?)
    end

    # Returns the planned duration after which the specified event will occur.
    def duration_of(event : Schedulable) : Duration
      precision = event.planned_precision
      duration = @current_time.duration_from_phase(event.planned_phase)
      rescaled_duration(duration, precision)
    end

    # Schedules a future event at a given planned *duration*.
    def plan_event(event : Schedulable, duration : Duration)
      planned_phase = @current_time.phase_from_duration(duration)

      event.planned_precision = duration.precision
      event.planned_phase = planned_phase

      @priority_queue.push(planned_phase, event)

      planned_phase
    end

    # Returns the planned `Duration` associated with the future imminent events
    # to occur, or `Duration::INFINIY` if `self` is empty.
    def imminent_duration : Duration
      if @priority_queue.empty?
        Duration::INFINITY
      else
        duration_of(@priority_queue.peek)
      end
    end

    # Deletes and returns the next imminent event to occur.
    def pop_imminent_event : Schedulable
      @priority_queue.pop
    end

    # Deletes and returns all imminent simultaneous events.
    def pop_imminent_events : Array(Schedulable)
      ary = [] of Schedulable
      @priority_queue.pop_imminents { |event| ary << event }
      ary
    end

    # Deletes and yields each imminent simultaneous event.
    def each_imminent_event
      @priority_queue.pop_imminents { |event| yield(event) }
    end

    def inspect(io)
      io << '<' << self.class.name
      io << ": current_time="
      @current_time.to_s(io)
      io << ", priority_queue="
      @priority_queue.inspect(io)
      io << '>'
    end

    protected def rescaled_duration(duration : Duration, precision : Scale) : Duration
      if duration.precision > precision
        @current_time.refined_duration(duration, precision)
      else
        Duration.new(duration.multiplier, precision)
      end
    end

    # Compares two planned phases that may have different precision levels.
    #
    # If *rhs_in_current_epoch* is `true`, when *b* overflows, it is considered
    # to be in the current epoch, or in the previous epoch relative to
    # `#current_time` instead of the next epoch.
    protected def cmp_planned_phases(a : Duration, b : Duration, rhs_in_current_epoch : Bool = false) : Int32
      # Avoid two conversions to planned durations if given planned phases
      # have same precision levels and if they are in the current epoch.
      if a.precision == b.precision
        epoch_phase = @current_time.epoch_phase(a.precision)
        if a.multiplier > epoch_phase && b.multiplier > epoch_phase
          return a <=> b
        end
      end

      duration_a = @current_time.duration_from_phase(a)
      duration_b = @current_time.duration_from_phase(b)

      if duration_a.precision < duration_b.precision
        duration_b = @current_time.refined_duration(duration_b, duration_a.precision)
      elsif duration_a.precision > duration_b.precision
        duration_a = @current_time.refined_duration(duration_a, duration_b.precision)
      end

      # if *b* overflowed and the flag is true, *b* is considered to be in the
      # current epoch.
      if rhs_in_current_epoch && (duration_b > b || b >= Duration.new(1, Scale.new(5)))
        # if *a* belongs to the next epoch, it is necessarily greater than *b*,
        # otherwise, operands should be swapped.
        if (duration_a > a || a >= Duration.new(1, Scale.new(5)))
          # special case for infinite values
          if duration_a.infinite? && duration_b.infinite?
            0
          elsif duration_b.infinite?
            -1
          else
            1
          end
        else
          if duration_b.infinite?
            -1
          else
            duration_b <=> duration_a
          end
        end
      else
        duration_a <=> duration_b
      end
    end
  end
end
