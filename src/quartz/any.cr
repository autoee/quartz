module Quartz
  # `Any` is a convenient wrapper around all possible Quartz types (`Any::Type`).
  # It is used to denote all types that may be transmitted between two `Port`s
  # through couplings.
  #
  # `Any` is used internally to store the outputs generated by atomic models
  # before presenting them to their receivers.
  struct Any
    # All possible Quartz types.
    #
    # See the `Transferable` marker module to extend the list of transferable
    # types.
    alias Type = Nil |
                 Bool |
                 Number::Primitive |
                 String |
                 Symbol |
                 Array(Any) |
                 Hash(Any, Any) |
                 Transferable

    # Returns the raw underlying value.
    getter raw : Type

    # Creates a `Any` value that wraps a new `Array`
    def self.array(initial_capacity : Int = 0) : self
      Any.new(Array(Any).new(initial_capacity))
    end

    # Creates a `Any` value that wraps a new `Hash`
    def self.hash(default_block : (Hash(K, V), K -> V)? = nil, initial_capacity = nil) : self
      Any.new(Hash(Any, Any).new(default_block, initial_capacity: initial_capacity))
    end

    def self.build_hash(default_block : (Hash(K, V), K -> V)? = nil, initial_capacity = nil) : self
      hash = Hash(Any, Any).new(default_block, initial_capacity: initial_capacity)
      yield hash
      Any.new(hash)
    end

    def self.build_array(initial_capacity : Int = 0) : self
      ary = Array(Any).new(initial_capacity)
      yield ary
      Any.new(ary)
    end

    # Creates a `Any` value that wraps the given value.
    def initialize(@raw : Type)
    end

    # See `Object#hash(hasher)`
    def_hash @raw

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

    # Assumes the underlying value is an `Array` and returns the element at the
    # given index.
    #
    # Raises if the underlying value is not an `Array`.
    def [](index : Int) : Any
      case object = @raw
      when Array
        object[index]
      else
        raise "Expected Array for #[](index : Int), not #{object.class}"
      end
    end

    # Assumes the underlying value is an `Array` and returns the element at the
    # given index, or `nil` if out of bounds.
    #
    # Raises if the underlying value is not an `Array`.
    def []?(index : Int) : Any
      case object = @raw
      when Array
        object[index]?
      else
        raise "Expected Array for #[](index : Int), not #{object.class}"
      end
    end

    # Assumes the underlying value is a `Hash` and returns the element with the
    # given key.
    #
    # Raises if the underlying value is not a `Hash`.
    def [](key : Any) : Any
      case object = @raw
      when Hash
        object[key]
      else
        raise "Expected Hash for #[](key : Any), not #{object.class}"
      end
    end

    # Assumes the underlying value is a `Hash` and returns the element with the
    # given key.
    #
    # Raises if the underlying value is not a `Hash`.
    def [](key : Any::Type) : Any
      case object = @raw
      when Hash
        object[Any.new(key)]
      else
        raise "Expected Hash for #[](key : Any::Type), not #{object.class}"
      end
    end

    # Assumes the underlying value is a `Hash` and returns the element with the
    # given key, or `nil` if the key is not present.
    #
    # Raises if the underlying value is not a `Hash`.
    def []?(key : Any) : Any
      case object = @raw
      when Hash
        object[key]?
      else
        raise "Expected Hash for #[](key : Any), not #{object.class}"
      end
    end

    # Assumes the underlying value is a `Array` and sets the given value at the
    # given index.
    def []=(index : Int, value : Any) : Any
      case object = @raw
      when Array
        object[index] = value
      else
        raise "Expected Array for #[](index : Int, value : Any), not #{object.class}"
      end
    end

    # Assumes the underlying value is a `Array` and sets the given value at the
    # given index.
    def []=(index : Int, value : Any::Type) : Any
      case object = @raw
      when Array
        object[index] = Any.new(value)
      else
        raise "Expected Array for #[](index : Int, value : Any::Type), not #{object.class}"
      end
    end

    # Assumes the underlying value is a `Hash` and sets the given value at the
    # given key.
    def []=(key : Any, value : Any) : Any
      case object = @raw
      when Hash
        object[key] = value
      else
        raise "Expected Hash for #[](index : Any, value : Any), not #{object.class}"
      end
    end

    # Assumes the underlying value is a `Hash` and sets the given value at the
    # given key.
    def []=(key : Any, value : Any::Type) : Any
      case object = @raw
      when Hash
        object[key] = Any.new(value)
      else
        raise "Expected Hash for #[](index : Any, value : Any::Type), not #{object.class}"
      end
    end

    # Assumes the underlying value is a `Hash` and sets the given value at the
    # given key.
    def []=(key : Any::Type, value : Any::Type) : Any
      case object = @raw
      when Hash
        object[Any.new(key)] = Any.new(value)
      else
        raise "Expected Hash for #[](index : Any::Type, value : Any::Type), not #{object.class}"
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

    # :nodoc:
    def pretty_print(pp)
      @raw.pretty_print(pp)
    end

    # Returns true if both `self` and *other*'s raw object are equal.
    def ==(other : Quartz::Any)
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

    # Checks that the underlying value is `Int`, and returns its value as an `UInt64`. Raises otherwise.
    def as_u128 : UInt64
      @raw.as(UInt128).to_u128
    end

    # Checks that the underlying value is `Int`, and returns its value as an `UInt64`. Raises otherwise.
    def as_u128? : (UInt64 | Nil)
      as_u128 if @raw.is_a?(UInt128)
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

    # Checks that the underlying value is `Int`, and returns its value as an `Int128`. Raises otherwise.
    def as_i128 : Int128
      @raw.as(Int128).to_i64
    end

    # Checks that the underlying value is `Int`, and returns its value as an `Int128`. Returns nil otherwise.
    def as_i128? : (Int128 | Nil)
      as_i128 if @raw.is_a?(Int128)
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
    def as_a : Array(Any)
      @raw.as(Array)
    end

    # Checks that the underlying value is `Array`, and returns its value. Returns nil otherwise.
    def as_a? : Array(Any)?
      as_a if @raw.is_a?(Array)
    end

    # Checks that the underlying value is `Hash`, and returns its value. Raises otherwise.
    def as_h : Hash(Any, Any)
      @raw.as(Hash)
    end

    # Checks that the underlying value is `Hash`, and returns its value. Returns nil otherwise.
    def as_h? : Hash(Any, Any)?
      as_h if @raw.is_a?(Hash)
    end

    def as_sym : Symbol
      @raw.as(Symbol)
    end

    def as_sym? : Symbol | Nil
      as_sym if @raw.is_a?(Symbol)
    end
  end

  class ::Object
    def ===(other : Quartz::Any)
      self === other.raw
    end
  end

  struct ::Value
    def ==(other : Quartz::Any)
      self == other.raw
    end
  end

  class ::Reference
    def ==(other : Quartz::Any)
      self == other.raw
    end
  end

  class ::Array
    def ==(other : Quartz::Any)
      self == other.raw
    end
  end

  class ::Hash
    def ==(other : Quartz::Any)
      self == other.raw
    end
  end

  class ::Regex
    def ===(other : Quartz::Any)
      value = self === other.raw
      $~ = $~
      value
    end
  end
end
