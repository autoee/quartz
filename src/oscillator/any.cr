module DEVS
  struct Any
    include Enumerable(self)

    getter raw : DEVS::Type

    def initialize(@raw : DEVS::Type)
    end

    def hash
      @raw.hash
    end

    # Assumes the underlying value is an `Array`, `Slice` or `Hash` and returns
    # its size.
    # Raises if the underlying value is not an `Array`, `Slice` or `Hash`.
    def size : Int
      case object = @raw
      when Array, Hash, Slice
        object.size
      else
        raise "expected Array, Slice or Hash for #size, not #{object.class}"
      end
    end

    # Assumes the underlying value is an `Array`, `Slice` or `Hash` and yields
    # each of the elements or key/values, always as `DEVS::Any`.
    # Raises if the underlying value is not an `Array`, `Slice` or `Hash`.
    def each
      case object = @raw
      when Array, Slice
        object.each do |elem|
          yield Any.new(elem), Any.new(nil)
        end
      when Hash
        object.each do |key, value|
          yield Any.new(key), Any.new(value)
        end
      else
        raise "expected Array, Slice or Hash for #each, not #{object.class}"
      end
    end

    # :nodoc:
    def inspect(io)
      @raw.inspect(io)
    end

    # :nodoc:
    def to_s(io)
      @raw.to_s(io)
    end

    # Returns true if both `self` and *other*'s raw object are equal.
    def ==(other : DEVS::Any)
      raw == other.raw
    end

    # Returns true if the raw object is equal to *other*.
    def ==(other)
      raw == other
    end

    # Checks that the underlying value is `Nil`, and returns `nil`. Raises otherwise.
    def as_nil : Nil
      @raw.as(Nil)
    end

    # Checks that the underlying value is `Bool`, and returns its value. Raises otherwise.
    def as_bool : Bool
      @raw.as(Bool)
    end

    # Checks that the underlying value is `Bool`, and returns its value. Returns nil otherwise.
    def as_bool? : (Bool | Nil)
      as_bool if @raw.is_a?(Bool)
    end

    # Checks that the underlying value is `Int`, and returns its value as an `UInt8`. Raises otherwise.
    def as_u8 : UInt8
      @raw.as(UInt8).to_u8
    end

    # Checks that the underlying value is `Int`, and returns its value as an `UInt8`. Returns nil otherwise.
    def as_u8? : (UInt8 | Nil)
      as_u8 if @raw.is_a?(UInt8)
    end

    # Checks that the underlying value is `Int`, and returns its value as an `UInt16`. Raises otherwise.
    def as_u16 : UInt16
      @raw.as(UInt16).to_u16
    end

    # Checks that the underlying value is `Int`, and returns its value as an `UInt16`. Returns nil otherwise.
    def as_u16? : (UInt16 | Nil)
      as_u16 if @raw.is_a?(UInt16)
    end

    # Checks that the underlying value is `Int`, and returns its value as an `UInt32`. Raises otherwise.
    def as_u32 : UInt32
      @raw.as(UInt32).to_u32
    end

    # Checks that the underlying value is `Int`, and returns its value as an `UInt32`. Returns nil otherwise.
    def as_u32? : (UInt32 | Nil)
      as_u32 if @raw.is_a?(UInt32)
    end

    # Checks that the underlying value is `Int`, and returns its value as an `UInt64`. Raises otherwise.
    def as_u64 : UInt64
      @raw.as(UInt64).to_u64
    end

    # Checks that the underlying value is `Int`, and returns its value as an `UInt64`. Returns nil otherwise.
    def as_u64? : (UInt64 | Nil)
      as_u64 if @raw.is_a?(UInt64)
    end

    # Checks that the underlying value is `Int`, and returns its value as an `Int8`. Raises otherwise.
    def as_i8 : Int8
      @raw.as(Int8).to_i8
    end

    # Checks that the underlying value is `Int`, and returns its value as an `Int8`. Returns nil otherwise.
    def as_i8? : (Int8 | Nil)
      as_i8 if @raw.is_a?(Int8)
    end

    # Checks that the underlying value is `Int`, and returns its value as an `Int16`. Raises otherwise.
    def as_i16 : Int16
      @raw.as(Int16).to_i16
    end

    # Checks that the underlying value is `Int`, and returns its value as an `Int16`. Returns nil otherwise.
    def as_i16? : (Int16 | Nil)
      as_i16 if @raw.is_a?(Int16)
    end

    # Checks that the underlying value is `Int`, and returns its value as an `Int32`. Raises otherwise.
    def as_i32 : Int32
      @raw.as(Int32).to_i32
    end

    # Checks that the underlying value is `Int`, and returns its value as an `Int32`. Returns nil otherwise.
    def as_i32? : (Int32 | Nil)
      as_i32 if @raw.is_a?(Int32)
    end

    # Checks that the underlying value is `Int`, and returns its value as an `Int64`. Raises otherwise.
    def as_i64 : Int64
      @raw.as(Int64).to_i64
    end

    # Checks that the underlying value is `Int`, and returns its value as an `Int64`. Returns nil otherwise.
    def as_i64? : (Int64 | Nil)
      as_i64 if @raw.is_a?(Int64)
    end

    # Checks that the underlying value is `Float`, and returns its value as an `Float64`. Raises otherwise.
    def as_f64 : Float64
      @raw.as(Float64).to_f64
    end

    # Checks that the underlying value is `Float`, and returns its value as an `Float64`. Returns nil otherwise.
    def as_f64? : (Float64 | Nil)
      as_f64 if @raw.is_a?(Float64)
    end

    # Checks that the underlying value is `Float`, and returns its value as an `Float32`. Raises otherwise.
    def as_f32 : Float32
      @raw.as(Float32).to_f32
    end

    # Checks that the underlying value is `Float`, and returns its value as an `Float32`. Returns nil otherwise.
    def as_f32? : (Float32 | Nil)
      as_f32 if (@raw.is_a?(Float32) || @raw.is_a?(Float64))
    end

    # Checks that the underlying value is `String`, and returns its value. Raises otherwise.
    def as_s : String
      @raw.as(String)
    end

    # Checks that the underlying value is `String`, and returns its value. Returns nil otherwise.
    def as_s? : (String | Nil)
      as_s if @raw.is_a?(String)
    end

    # Checks that the underlying value is `Array`, and returns its value. Raises otherwise.
    def as_a : Array(Type)
      @raw.as(Array)
    end

    # Checks that the underlying value is `Array`, and returns its value. Returns nil otherwise.
    def as_a? : (Array(Type) | Nil)
      as_a if @raw.is_a?(Array(Type))
    end

    # Checks that the underlying value is `Hash`, and returns its value. Raises otherwise.
    def as_h : Hash(Type, Type)
      @raw.as(Hash)
    end

    # Checks that the underlying value is `Hash`, and returns its value. Returns nil otherwise.
    def as_h? : (Hash(String, Type) | Nil)
      as_h if @raw.is_a?(Hash(String, Type))
    end

    def as_sym : Symbol
      @raw.as(Symbol)
    end

    def as_sym? : Symbol | Nil
      as_sym if @raw.is_a?(Symbol)
    end

    def as_slice : Slice(Type)
      @raw.as(Slice(Type))
    end

    def as_slice? : Slice(Type) | Nil
      as_slice if @raw.is_a?(Slice(Type))
    end
  end
end
