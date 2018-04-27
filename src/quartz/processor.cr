module Quartz
  abstract class Processor
    include Schedulable

    # :nodoc:
    OBS_INFO_INIT_PHASE = {:phase => Any.new(:init)}
    # :nodoc:
    OBS_INFO_COLLECT_PHASE = {:phase => Any.new(:collect_outputs)}
    # :nodoc:
    OBS_INFO_TRANSITIONS_PHASE = {:phase => Any.new(:perform_transitions)}
    # :nodoc:
    EMPTY_BAG = Hash(InputPort, Array(Any)).new

    include Logging

    getter model : Model
    property sync : Bool
    property parent : Coordinator?

    @bag : Hash(InputPort, Array(Any))?

    def initialize(@model : Model)
      @sync = false
      @model.processor = self
    end

    def bag
      @bag ||= Hash(InputPort, Array(Any)).new { |h, k| h[k] = Array(Any).new }
    end

    def bag?
      @bag
    end

    def inspect(io)
      io << "<" << self.class.name << ": tn=" << @time_next.to_s(io)
      io << ", tl=" << @time_last.to_s(io) << ">"
      nil
    end

    abstract def initialize_processor(time : TimePoint) : {Duration, Duration}
    abstract def collect_outputs(time : TimePoint) : Hash(OutputPort, Any)
    abstract def perform_transitions(planned : Duration, elapsed : Duration) : Duration
  end
end
