module Quartz
  # The `Name` alias is used in Quartz to denote the name of a `Model` or the
  # name of a `Port`.
  alias Name = String | Symbol

  # The `Transferable` module is used in Quartz as a marker interface to denote
  # types that may be transmitted between two `Port`s through couplings.
  # The common types included in the union `Type` can be transferred, but if
  # you need to extend those types, `Transferable` marker module should be
  # included.
  #
  # Until crystal compiler is able to store virtual types as an ivar, we use
  # this workaround (see crystal issue #1839).
  #
  # Usage:
  # ```
  # class MyType
  #   include Quartz::Transferable
  #   # ...
  # end
  #
  # class SenderModel < Quartz::AtomicModel
  #   output :oport
  #
  #   def output
  #     post MyType.new, on: :oport
  #   end
  # end
  # ```
  #
  # For existing types that are not included in the union `Type`, you can
  # re-open its definition and include `Transferable`:
  # ```
  # struct BigInt
  #   include Transferable
  # end
  # ```
  module Transferable
  end

  # `AnyNumber` is an alias defined for convenience.
  alias AnyNumber = Int8 |
                    Int16 |
                    Int32 |
                    Int64 |
                    UInt8 |
                    UInt16 |
                    UInt32 |
                    UInt64 |
                    Float32 |
                    Float64

  # The `Type` alias is used to denote all types that may be transmitted
  # between two `Port`s through couplings.
  #
  # See the `Transferable` marker module to extend the list of transferable
  # types.
  alias Type = Nil |
               Bool |
               AnyNumber |
               String |
               Symbol |
               Array(Type) |
               Hash(Type, Type) |
               Transferable

  # TODO Rename to virtual time, use an interface ?
  alias SimulationTime = AnyNumber

  INFINITY = Float32::INFINITY
end