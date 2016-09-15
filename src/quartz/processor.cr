module Quartz

  abstract class Processor#(T)

    #include Logging
    #include Comparable(self)

    getter model : Model
    getter time_next : SimulationTime
    getter time_last : SimulationTime
    property parent : Coordinator?

    def initialize(@model : Model)
      @time_next = 0
      @time_last = 0
      @model.processor = self
    end

    # The comparison operator. Compares two processors given their #time_next
    #
    # @param other [Processor]
    # @return [Integer]
    # def <=>(other)
    #   other.time_next <=> @time_next
    # end

    def inspect(io)
      io << "<" << self.class.name << ": tn=" << @time_next.to_s(io)
      io << ", tl=" << @time_last.to_s(io) << ">"
      nil
    end
  end
end
