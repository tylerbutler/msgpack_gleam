/// Bidirectional codecs for MessagePack serialization.
///
/// Codecs combine encoding and decoding into a single definition,
/// eliminating the need to write separate encoder and decoder functions.
///
/// ## Example
///
/// ```gleam
/// import msgpack_gleam/codec.{type Codec}
///
/// pub type Person {
///   Person(name: String, age: Int)
/// }
///
/// pub fn person_codec() -> Codec(Person) {
///   codec.object2(
///     Person,
///     codec.field("name", codec.string(), fn(p) { p.name }),
///     codec.field("age", codec.int(), fn(p) { p.age }),
///   )
/// }
/// ```
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import msgpack_gleam/value.{type Value}

// ============================================================================
// Types
// ============================================================================

/// A bidirectional codec that can both encode and decode values of type `a`.
pub type Codec(a) {
  Codec(encoder: fn(a) -> Value, decoder: fn(Value) -> Result(a, DecodeError))
}

/// Errors that can occur during decoding.
pub type DecodeError {
  /// Expected a different type
  TypeMismatch(expected: String, got: String)
  /// Missing required field in map
  MissingField(field: String)
  /// Field exists but failed to decode
  FieldError(field: String, inner: DecodeError)
  /// Array element failed to decode
  IndexError(index: Int, inner: DecodeError)
  /// Extension type code mismatch
  ExtensionTypeMismatch(expected: Int, got: Int)
  /// Value out of expected range
  OutOfRange(message: String)
  /// Custom error message
  CustomError(message: String)
  /// Multiple errors collected
  AllFailed(errors: List(DecodeError))
}

/// A field definition for object codecs.
/// Contains the field name, its codec, and an accessor function.
pub type Field(record, field_type) {
  Field(
    name: String,
    codec: Codec(field_type),
    accessor: fn(record) -> field_type,
  )
}

// ============================================================================
// Core Functions
// ============================================================================

/// Encode a value using a codec.
pub fn encode(codec: Codec(a), val: a) -> Value {
  codec.encoder(val)
}

/// Decode a value using a codec.
pub fn decode(codec: Codec(a), val: Value) -> Result(a, DecodeError) {
  codec.decoder(val)
}

/// Create a custom codec from encoder and decoder functions.
pub fn custom(
  encoder: fn(a) -> Value,
  decoder: fn(Value) -> Result(a, DecodeError),
) -> Codec(a) {
  Codec(encoder:, decoder:)
}

// ============================================================================
// Primitive Codecs
// ============================================================================

/// Codec for boolean values.
pub fn bool() -> Codec(Bool) {
  Codec(encoder: fn(b) { value.Boolean(b) }, decoder: fn(v) {
    case v {
      value.Boolean(b) -> Ok(b)
      other -> Error(TypeMismatch("Boolean", value_type_name(other)))
    }
  })
}

/// Codec for integer values.
pub fn int() -> Codec(Int) {
  Codec(encoder: fn(i) { value.Integer(i) }, decoder: fn(v) {
    case v {
      value.Integer(i) -> Ok(i)
      other -> Error(TypeMismatch("Integer", value_type_name(other)))
    }
  })
}

/// Codec for float values.
/// When decoding, integers are automatically coerced to floats.
pub fn float() -> Codec(Float) {
  Codec(encoder: fn(f) { value.Float(f) }, decoder: fn(v) {
    case v {
      value.Float(f) -> Ok(f)
      value.Integer(i) -> Ok(int.to_float(i))
      other -> Error(TypeMismatch("Float", value_type_name(other)))
    }
  })
}

/// Codec for float values with strict type checking.
/// Integers are NOT coerced to floats.
pub fn float_strict() -> Codec(Float) {
  Codec(encoder: fn(f) { value.Float(f) }, decoder: fn(v) {
    case v {
      value.Float(f) -> Ok(f)
      other -> Error(TypeMismatch("Float", value_type_name(other)))
    }
  })
}

/// Codec for string values.
pub fn string() -> Codec(String) {
  Codec(encoder: fn(s) { value.String(s) }, decoder: fn(v) {
    case v {
      value.String(s) -> Ok(s)
      other -> Error(TypeMismatch("String", value_type_name(other)))
    }
  })
}

/// Codec for binary data.
pub fn binary() -> Codec(BitArray) {
  Codec(encoder: fn(b) { value.Binary(b) }, decoder: fn(v) {
    case v {
      value.Binary(b) -> Ok(b)
      other -> Error(TypeMismatch("Binary", value_type_name(other)))
    }
  })
}

/// Codec for raw MessagePack values (identity codec).
/// Useful when you want to preserve values without interpretation.
pub fn raw_value() -> Codec(Value) {
  Codec(encoder: fn(v) { v }, decoder: fn(v) { Ok(v) })
}

// ============================================================================
// Composite Codecs
// ============================================================================

/// Codec for optional values.
/// Encodes `None` as MessagePack Nil, `Some(x)` using the inner codec.
pub fn nullable(inner: Codec(a)) -> Codec(Option(a)) {
  Codec(
    encoder: fn(opt) {
      case opt {
        Some(a) -> inner.encoder(a)
        None -> value.Nil
      }
    },
    decoder: fn(v) {
      case v {
        value.Nil -> Ok(None)
        other ->
          case inner.decoder(other) {
            Ok(a) -> Ok(Some(a))
            Error(e) -> Error(e)
          }
      }
    },
  )
}

/// Codec for lists/arrays.
pub fn list(item: Codec(a)) -> Codec(List(a)) {
  Codec(
    encoder: fn(items) { value.Array(list.map(items, item.encoder)) },
    decoder: fn(v) {
      case v {
        value.Array(items) -> decode_list_items(items, item.decoder, 0, [])
        other -> Error(TypeMismatch("Array", value_type_name(other)))
      }
    },
  )
}

fn decode_list_items(
  items: List(Value),
  decoder: fn(Value) -> Result(a, DecodeError),
  index: Int,
  acc: List(a),
) -> Result(List(a), DecodeError) {
  case items {
    [] -> Ok(list.reverse(acc))
    [head, ..tail] ->
      case decoder(head) {
        Ok(decoded) ->
          decode_list_items(tail, decoder, index + 1, [decoded, ..acc])
        Error(e) -> Error(IndexError(index, e))
      }
  }
}

/// Codec for dictionaries with string keys.
pub fn string_dict(value_codec: Codec(v)) -> Codec(Dict(String, v)) {
  Codec(
    encoder: fn(d) {
      value.Map(
        dict.to_list(d)
        |> list.map(fn(pair) {
          #(value.String(pair.0), value_codec.encoder(pair.1))
        }),
      )
    },
    decoder: fn(v) {
      case v {
        value.Map(pairs) ->
          decode_string_dict_pairs(pairs, value_codec.decoder, dict.new())
        other -> Error(TypeMismatch("Map", value_type_name(other)))
      }
    },
  )
}

fn decode_string_dict_pairs(
  pairs: List(#(Value, Value)),
  value_decoder: fn(Value) -> Result(v, DecodeError),
  acc: Dict(String, v),
) -> Result(Dict(String, v), DecodeError) {
  case pairs {
    [] -> Ok(acc)
    [#(key, val), ..rest] ->
      case key {
        value.String(k) ->
          case value_decoder(val) {
            Ok(decoded) ->
              decode_string_dict_pairs(
                rest,
                value_decoder,
                dict.insert(acc, k, decoded),
              )
            Error(e) -> Error(FieldError(k, e))
          }
        other -> Error(TypeMismatch("String key", value_type_name(other)))
      }
  }
}

/// Codec for dictionaries with arbitrary key types.
pub fn dict(key_codec: Codec(k), value_codec: Codec(v)) -> Codec(Dict(k, v)) {
  Codec(
    encoder: fn(d) {
      value.Map(
        dict.to_list(d)
        |> list.map(fn(pair) {
          #(key_codec.encoder(pair.0), value_codec.encoder(pair.1))
        }),
      )
    },
    decoder: fn(v) {
      case v {
        value.Map(pairs) ->
          decode_dict_pairs(
            pairs,
            key_codec.decoder,
            value_codec.decoder,
            dict.new(),
          )
        other -> Error(TypeMismatch("Map", value_type_name(other)))
      }
    },
  )
}

fn decode_dict_pairs(
  pairs: List(#(Value, Value)),
  key_decoder: fn(Value) -> Result(k, DecodeError),
  value_decoder: fn(Value) -> Result(v, DecodeError),
  acc: Dict(k, v),
) -> Result(Dict(k, v), DecodeError) {
  case pairs {
    [] -> Ok(acc)
    [#(key, val), ..rest] ->
      case key_decoder(key), value_decoder(val) {
        Ok(k), Ok(v) ->
          decode_dict_pairs(
            rest,
            key_decoder,
            value_decoder,
            dict.insert(acc, k, v),
          )
        Error(e), _ ->
          Error(CustomError("Failed to decode map key: " <> format_error(e)))
        _, Error(e) ->
          Error(CustomError("Failed to decode map value: " <> format_error(e)))
      }
  }
}

/// Codec for MessagePack extension types.
pub fn extension(type_code: Int) -> Codec(BitArray) {
  Codec(encoder: fn(data) { value.Extension(type_code, data) }, decoder: fn(v) {
    case v {
      value.Extension(tc, data) if tc == type_code -> Ok(data)
      value.Extension(tc, _) -> Error(ExtensionTypeMismatch(type_code, tc))
      other -> Error(TypeMismatch("Extension", value_type_name(other)))
    }
  })
}

/// Codec for any extension type (returns type code and data).
pub fn any_extension() -> Codec(#(Int, BitArray)) {
  Codec(
    encoder: fn(pair: #(Int, BitArray)) { value.Extension(pair.0, pair.1) },
    decoder: fn(v) {
      case v {
        value.Extension(tc, data) -> Ok(#(tc, data))
        other -> Error(TypeMismatch("Extension", value_type_name(other)))
      }
    },
  )
}

// ============================================================================
// Field Helper
// ============================================================================

/// Create a field definition for use with object codecs.
pub fn field(
  name: String,
  codec: Codec(field_type),
  accessor: fn(record) -> field_type,
) -> Field(record, field_type) {
  Field(name:, codec:, accessor:)
}

// ============================================================================
// Object Codecs (Record Builders)
// ============================================================================

/// Codec for objects with 1 field.
pub fn object1(
  constructor: fn(a) -> record,
  field1: Field(record, a),
) -> Codec(record) {
  Codec(
    encoder: fn(record) {
      value.Map([
        #(
          value.String(field1.name),
          field1.codec.encoder(field1.accessor(record)),
        ),
      ])
    },
    decoder: fn(v) {
      use a <- result.try(decode_field(v, field1))
      Ok(constructor(a))
    },
  )
}

/// Codec for objects with 2 fields.
pub fn object2(
  constructor: fn(a, b) -> record,
  field1: Field(record, a),
  field2: Field(record, b),
) -> Codec(record) {
  Codec(
    encoder: fn(record) {
      value.Map([
        #(
          value.String(field1.name),
          field1.codec.encoder(field1.accessor(record)),
        ),
        #(
          value.String(field2.name),
          field2.codec.encoder(field2.accessor(record)),
        ),
      ])
    },
    decoder: fn(v) {
      use a <- result.try(decode_field(v, field1))
      use b <- result.try(decode_field(v, field2))
      Ok(constructor(a, b))
    },
  )
}

/// Codec for objects with 3 fields.
pub fn object3(
  constructor: fn(a, b, c) -> record,
  field1: Field(record, a),
  field2: Field(record, b),
  field3: Field(record, c),
) -> Codec(record) {
  Codec(
    encoder: fn(record) {
      value.Map([
        #(
          value.String(field1.name),
          field1.codec.encoder(field1.accessor(record)),
        ),
        #(
          value.String(field2.name),
          field2.codec.encoder(field2.accessor(record)),
        ),
        #(
          value.String(field3.name),
          field3.codec.encoder(field3.accessor(record)),
        ),
      ])
    },
    decoder: fn(v) {
      use a <- result.try(decode_field(v, field1))
      use b <- result.try(decode_field(v, field2))
      use c <- result.try(decode_field(v, field3))
      Ok(constructor(a, b, c))
    },
  )
}

/// Codec for objects with 4 fields.
pub fn object4(
  constructor: fn(a, b, c, d) -> record,
  field1: Field(record, a),
  field2: Field(record, b),
  field3: Field(record, c),
  field4: Field(record, d),
) -> Codec(record) {
  Codec(
    encoder: fn(record) {
      value.Map([
        #(
          value.String(field1.name),
          field1.codec.encoder(field1.accessor(record)),
        ),
        #(
          value.String(field2.name),
          field2.codec.encoder(field2.accessor(record)),
        ),
        #(
          value.String(field3.name),
          field3.codec.encoder(field3.accessor(record)),
        ),
        #(
          value.String(field4.name),
          field4.codec.encoder(field4.accessor(record)),
        ),
      ])
    },
    decoder: fn(v) {
      use a <- result.try(decode_field(v, field1))
      use b <- result.try(decode_field(v, field2))
      use c <- result.try(decode_field(v, field3))
      use d <- result.try(decode_field(v, field4))
      Ok(constructor(a, b, c, d))
    },
  )
}

/// Codec for objects with 5 fields.
pub fn object5(
  constructor: fn(a, b, c, d, e) -> record,
  field1: Field(record, a),
  field2: Field(record, b),
  field3: Field(record, c),
  field4: Field(record, d),
  field5: Field(record, e),
) -> Codec(record) {
  Codec(
    encoder: fn(record) {
      value.Map([
        #(
          value.String(field1.name),
          field1.codec.encoder(field1.accessor(record)),
        ),
        #(
          value.String(field2.name),
          field2.codec.encoder(field2.accessor(record)),
        ),
        #(
          value.String(field3.name),
          field3.codec.encoder(field3.accessor(record)),
        ),
        #(
          value.String(field4.name),
          field4.codec.encoder(field4.accessor(record)),
        ),
        #(
          value.String(field5.name),
          field5.codec.encoder(field5.accessor(record)),
        ),
      ])
    },
    decoder: fn(v) {
      use a <- result.try(decode_field(v, field1))
      use b <- result.try(decode_field(v, field2))
      use c <- result.try(decode_field(v, field3))
      use d <- result.try(decode_field(v, field4))
      use e <- result.try(decode_field(v, field5))
      Ok(constructor(a, b, c, d, e))
    },
  )
}

/// Codec for objects with 6 fields.
pub fn object6(
  constructor: fn(a, b, c, d, e, f) -> record,
  field1: Field(record, a),
  field2: Field(record, b),
  field3: Field(record, c),
  field4: Field(record, d),
  field5: Field(record, e),
  field6: Field(record, f),
) -> Codec(record) {
  Codec(
    encoder: fn(record) {
      value.Map([
        #(
          value.String(field1.name),
          field1.codec.encoder(field1.accessor(record)),
        ),
        #(
          value.String(field2.name),
          field2.codec.encoder(field2.accessor(record)),
        ),
        #(
          value.String(field3.name),
          field3.codec.encoder(field3.accessor(record)),
        ),
        #(
          value.String(field4.name),
          field4.codec.encoder(field4.accessor(record)),
        ),
        #(
          value.String(field5.name),
          field5.codec.encoder(field5.accessor(record)),
        ),
        #(
          value.String(field6.name),
          field6.codec.encoder(field6.accessor(record)),
        ),
      ])
    },
    decoder: fn(v) {
      use a <- result.try(decode_field(v, field1))
      use b <- result.try(decode_field(v, field2))
      use c <- result.try(decode_field(v, field3))
      use d <- result.try(decode_field(v, field4))
      use e <- result.try(decode_field(v, field5))
      use f <- result.try(decode_field(v, field6))
      Ok(constructor(a, b, c, d, e, f))
    },
  )
}

/// Codec for objects with 7 fields.
pub fn object7(
  constructor: fn(a, b, c, d, e, f, g) -> record,
  field1: Field(record, a),
  field2: Field(record, b),
  field3: Field(record, c),
  field4: Field(record, d),
  field5: Field(record, e),
  field6: Field(record, f),
  field7: Field(record, g),
) -> Codec(record) {
  Codec(
    encoder: fn(record) {
      value.Map([
        #(
          value.String(field1.name),
          field1.codec.encoder(field1.accessor(record)),
        ),
        #(
          value.String(field2.name),
          field2.codec.encoder(field2.accessor(record)),
        ),
        #(
          value.String(field3.name),
          field3.codec.encoder(field3.accessor(record)),
        ),
        #(
          value.String(field4.name),
          field4.codec.encoder(field4.accessor(record)),
        ),
        #(
          value.String(field5.name),
          field5.codec.encoder(field5.accessor(record)),
        ),
        #(
          value.String(field6.name),
          field6.codec.encoder(field6.accessor(record)),
        ),
        #(
          value.String(field7.name),
          field7.codec.encoder(field7.accessor(record)),
        ),
      ])
    },
    decoder: fn(v) {
      use a <- result.try(decode_field(v, field1))
      use b <- result.try(decode_field(v, field2))
      use c <- result.try(decode_field(v, field3))
      use d <- result.try(decode_field(v, field4))
      use e <- result.try(decode_field(v, field5))
      use f <- result.try(decode_field(v, field6))
      use g <- result.try(decode_field(v, field7))
      Ok(constructor(a, b, c, d, e, f, g))
    },
  )
}

/// Codec for objects with 8 fields.
pub fn object8(
  constructor: fn(a, b, c, d, e, f, g, h) -> record,
  field1: Field(record, a),
  field2: Field(record, b),
  field3: Field(record, c),
  field4: Field(record, d),
  field5: Field(record, e),
  field6: Field(record, f),
  field7: Field(record, g),
  field8: Field(record, h),
) -> Codec(record) {
  Codec(
    encoder: fn(record) {
      value.Map([
        #(
          value.String(field1.name),
          field1.codec.encoder(field1.accessor(record)),
        ),
        #(
          value.String(field2.name),
          field2.codec.encoder(field2.accessor(record)),
        ),
        #(
          value.String(field3.name),
          field3.codec.encoder(field3.accessor(record)),
        ),
        #(
          value.String(field4.name),
          field4.codec.encoder(field4.accessor(record)),
        ),
        #(
          value.String(field5.name),
          field5.codec.encoder(field5.accessor(record)),
        ),
        #(
          value.String(field6.name),
          field6.codec.encoder(field6.accessor(record)),
        ),
        #(
          value.String(field7.name),
          field7.codec.encoder(field7.accessor(record)),
        ),
        #(
          value.String(field8.name),
          field8.codec.encoder(field8.accessor(record)),
        ),
      ])
    },
    decoder: fn(v) {
      use a <- result.try(decode_field(v, field1))
      use b <- result.try(decode_field(v, field2))
      use c <- result.try(decode_field(v, field3))
      use d <- result.try(decode_field(v, field4))
      use e <- result.try(decode_field(v, field5))
      use f <- result.try(decode_field(v, field6))
      use g <- result.try(decode_field(v, field7))
      use h <- result.try(decode_field(v, field8))
      Ok(constructor(a, b, c, d, e, f, g, h))
    },
  )
}

// ============================================================================
// Codec Combinators
// ============================================================================

/// Transform a codec's values using bidirectional mapping functions.
pub fn map(
  codec: Codec(a),
  encode_map: fn(b) -> a,
  decode_map: fn(a) -> b,
) -> Codec(b) {
  Codec(encoder: fn(b) { codec.encoder(encode_map(b)) }, decoder: fn(v) {
    result.map(codec.decoder(v), decode_map)
  })
}

/// Transform a codec with a fallible decode mapping.
pub fn try_map(
  codec: Codec(a),
  encode_map: fn(b) -> a,
  decode_map: fn(a) -> Result(b, DecodeError),
) -> Codec(b) {
  Codec(encoder: fn(b) { codec.encoder(encode_map(b)) }, decoder: fn(v) {
    result.try(codec.decoder(v), decode_map)
  })
}

/// Try multiple codecs in order, using the first that succeeds for decoding.
/// Encoding uses the first codec.
pub fn one_of(codecs: List(Codec(a))) -> Codec(a) {
  case codecs {
    [] ->
      Codec(encoder: fn(_) { value.Nil }, decoder: fn(_) {
        Error(CustomError("No codecs provided to one_of"))
      })
    [first, ..rest] ->
      Codec(encoder: first.encoder, decoder: fn(v) {
        try_codecs(v, [first, ..rest], [])
      })
  }
}

fn try_codecs(
  v: Value,
  codecs: List(Codec(a)),
  errors: List(DecodeError),
) -> Result(a, DecodeError) {
  case codecs {
    [] -> Error(AllFailed(list.reverse(errors)))
    [codec, ..rest] ->
      case codec.decoder(v) {
        Ok(a) -> Ok(a)
        Error(e) -> try_codecs(v, rest, [e, ..errors])
      }
  }
}

/// Create a codec that always succeeds with a constant value when decoding.
/// Useful for default values or variant tags.
pub fn succeed(val: a) -> Codec(a) {
  Codec(encoder: fn(_) { value.Nil }, decoder: fn(_) { Ok(val) })
}

/// Create a codec that always fails with the given error.
pub fn fail(error: String) -> Codec(a) {
  Codec(encoder: fn(_) { value.Nil }, decoder: fn(_) {
    Error(CustomError(error))
  })
}

/// Add a default value for when decoding fails.
pub fn with_default(codec: Codec(a), default: a) -> Codec(a) {
  Codec(encoder: codec.encoder, decoder: fn(v) {
    case codec.decoder(v) {
      Ok(a) -> Ok(a)
      Error(_) -> Ok(default)
    }
  })
}

/// Lazy codec evaluation for recursive types.
pub fn lazy(make_codec: fn() -> Codec(a)) -> Codec(a) {
  Codec(encoder: fn(a) { make_codec().encoder(a) }, decoder: fn(v) {
    make_codec().decoder(v)
  })
}

// ============================================================================
// Tuple Codecs
// ============================================================================

/// Codec for 2-tuples encoded as arrays.
pub fn tuple2(codec1: Codec(a), codec2: Codec(b)) -> Codec(#(a, b)) {
  Codec(
    encoder: fn(t: #(a, b)) {
      value.Array([codec1.encoder(t.0), codec2.encoder(t.1)])
    },
    decoder: fn(v) {
      case v {
        value.Array([v1, v2]) -> {
          use a <- result.try(map_index_error(codec1.decoder(v1), 0))
          use b <- result.try(map_index_error(codec2.decoder(v2), 1))
          Ok(#(a, b))
        }
        value.Array(items) ->
          Error(CustomError(
            "Expected array of 2 elements, got "
            <> int.to_string(list.length(items)),
          ))
        other -> Error(TypeMismatch("Array", value_type_name(other)))
      }
    },
  )
}

/// Codec for 3-tuples encoded as arrays.
pub fn tuple3(
  codec1: Codec(a),
  codec2: Codec(b),
  codec3: Codec(c),
) -> Codec(#(a, b, c)) {
  Codec(
    encoder: fn(t: #(a, b, c)) {
      value.Array([
        codec1.encoder(t.0),
        codec2.encoder(t.1),
        codec3.encoder(t.2),
      ])
    },
    decoder: fn(v) {
      case v {
        value.Array([v1, v2, v3]) -> {
          use a <- result.try(map_index_error(codec1.decoder(v1), 0))
          use b <- result.try(map_index_error(codec2.decoder(v2), 1))
          use c <- result.try(map_index_error(codec3.decoder(v3), 2))
          Ok(#(a, b, c))
        }
        value.Array(items) ->
          Error(CustomError(
            "Expected array of 3 elements, got "
            <> int.to_string(list.length(items)),
          ))
        other -> Error(TypeMismatch("Array", value_type_name(other)))
      }
    },
  )
}

/// Codec for 4-tuples encoded as arrays.
pub fn tuple4(
  codec1: Codec(a),
  codec2: Codec(b),
  codec3: Codec(c),
  codec4: Codec(d),
) -> Codec(#(a, b, c, d)) {
  Codec(
    encoder: fn(t: #(a, b, c, d)) {
      value.Array([
        codec1.encoder(t.0),
        codec2.encoder(t.1),
        codec3.encoder(t.2),
        codec4.encoder(t.3),
      ])
    },
    decoder: fn(v) {
      case v {
        value.Array([v1, v2, v3, v4]) -> {
          use a <- result.try(map_index_error(codec1.decoder(v1), 0))
          use b <- result.try(map_index_error(codec2.decoder(v2), 1))
          use c <- result.try(map_index_error(codec3.decoder(v3), 2))
          use d <- result.try(map_index_error(codec4.decoder(v4), 3))
          Ok(#(a, b, c, d))
        }
        value.Array(items) ->
          Error(CustomError(
            "Expected array of 4 elements, got "
            <> int.to_string(list.length(items)),
          ))
        other -> Error(TypeMismatch("Array", value_type_name(other)))
      }
    },
  )
}

// ============================================================================
// Constrained Codecs
// ============================================================================

/// Codec for integers within a specific range.
pub fn int_range(min: Int, max: Int) -> Codec(Int) {
  Codec(encoder: fn(i) { value.Integer(i) }, decoder: fn(v) {
    case v {
      value.Integer(i) if i >= min && i <= max -> Ok(i)
      value.Integer(i) ->
        Error(OutOfRange(
          "Integer "
          <> int.to_string(i)
          <> " not in range ["
          <> int.to_string(min)
          <> ", "
          <> int.to_string(max)
          <> "]",
        ))
      other -> Error(TypeMismatch("Integer", value_type_name(other)))
    }
  })
}

/// Codec for non-empty strings.
pub fn non_empty_string() -> Codec(String) {
  Codec(encoder: fn(s) { value.String(s) }, decoder: fn(v) {
    case v {
      value.String(s) if s != "" -> Ok(s)
      value.String(_) -> Error(OutOfRange("String must not be empty"))
      other -> Error(TypeMismatch("String", value_type_name(other)))
    }
  })
}

/// Codec for non-empty lists.
pub fn non_empty_list(item: Codec(a)) -> Codec(List(a)) {
  Codec(
    encoder: fn(items) { value.Array(list.map(items, item.encoder)) },
    decoder: fn(v) {
      case v {
        value.Array([]) -> Error(OutOfRange("List must not be empty"))
        value.Array(items) -> decode_list_items(items, item.decoder, 0, [])
        other -> Error(TypeMismatch("Array", value_type_name(other)))
      }
    },
  )
}

// ============================================================================
// Helper Functions
// ============================================================================

fn decode_field(v: Value, field_def: Field(record, a)) -> Result(a, DecodeError) {
  case v {
    value.Map(pairs) ->
      case find_field_in_pairs(pairs, field_def.name) {
        Ok(field_value) ->
          case field_def.codec.decoder(field_value) {
            Ok(a) -> Ok(a)
            Error(e) -> Error(FieldError(field_def.name, e))
          }
        Error(_) -> Error(MissingField(field_def.name))
      }
    other -> Error(TypeMismatch("Map", value_type_name(other)))
  }
}

fn find_field_in_pairs(
  pairs: List(#(Value, Value)),
  name: String,
) -> Result(Value, DecodeError) {
  case pairs {
    [] -> Error(MissingField(name))
    [#(value.String(key), val), ..rest] ->
      case key == name {
        True -> Ok(val)
        False -> find_field_in_pairs(rest, name)
      }
    [_, ..rest] -> find_field_in_pairs(rest, name)
  }
}

fn map_index_error(
  res: Result(a, DecodeError),
  index: Int,
) -> Result(a, DecodeError) {
  case res {
    Ok(a) -> Ok(a)
    Error(e) -> Error(IndexError(index, e))
  }
}

fn value_type_name(v: Value) -> String {
  case v {
    value.Nil -> "Nil"
    value.Boolean(_) -> "Boolean"
    value.Integer(_) -> "Integer"
    value.Float(_) -> "Float"
    value.String(_) -> "String"
    value.Binary(_) -> "Binary"
    value.Array(_) -> "Array"
    value.Map(_) -> "Map"
    value.Extension(_, _) -> "Extension"
  }
}

// ============================================================================
// Error Formatting
// ============================================================================

/// Format a decode error as a human-readable string.
pub fn format_error(error: DecodeError) -> String {
  format_error_inner(error, "")
}

fn format_error_inner(error: DecodeError, path: String) -> String {
  case error {
    TypeMismatch(expected, got) ->
      path_prefix(path) <> "expected " <> expected <> ", got " <> got
    MissingField(name) ->
      path_prefix(path) <> "missing field \"" <> name <> "\""
    FieldError(name, inner) ->
      format_error_inner(inner, append_path(path, "." <> name))
    IndexError(index, inner) ->
      format_error_inner(
        inner,
        append_path(path, "[" <> int.to_string(index) <> "]"),
      )
    ExtensionTypeMismatch(expected, got) ->
      path_prefix(path)
      <> "expected extension type "
      <> int.to_string(expected)
      <> ", got "
      <> int.to_string(got)
    OutOfRange(message) -> path_prefix(path) <> message
    CustomError(message) -> path_prefix(path) <> message
    AllFailed(errors) ->
      path_prefix(path)
      <> "all alternatives failed: ["
      <> string.join(list.map(errors, format_error), ", ")
      <> "]"
  }
}

fn path_prefix(path: String) -> String {
  case path {
    "" -> ""
    p -> "at " <> p <> ": "
  }
}

fn append_path(base: String, suffix: String) -> String {
  case base {
    "" -> "$" <> suffix
    p -> p <> suffix
  }
}
