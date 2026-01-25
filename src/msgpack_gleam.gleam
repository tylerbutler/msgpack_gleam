/// A pure Gleam implementation of MessagePack.
///
/// MessagePack is an efficient binary serialization format that lets you
/// exchange data among multiple languages like JSON, but faster and smaller.
///
/// ## Quick Start
///
/// ```gleam
/// import msgpack_gleam.{pack, unpack_exact}
/// import msgpack_gleam/value.{Integer, String, Array}
///
/// // Encode a value
/// let assert Ok(data) = pack(Array([String("hello"), Integer(42)]))
///
/// // Decode it back
/// let assert Ok(value) = unpack_exact(data)
/// // value == Array([String("hello"), Integer(42)])
/// ```
///
/// ## Value Types
///
/// MessagePack supports the following value types:
/// - `Nil` - null value
/// - `Boolean(Bool)` - true/false
/// - `Integer(Int)` - integers (encoded efficiently based on size)
/// - `Float(Float)` - floating point numbers
/// - `String(String)` - UTF-8 strings
/// - `Binary(BitArray)` - raw binary data
/// - `Array(List(Value))` - ordered collections
/// - `Map(List(#(Value, Value)))` - key-value pairs (preserves order)
/// - `Extension(type_code, data)` - custom extension types
///
/// ## Timestamps
///
/// MessagePack has a built-in timestamp extension type. Use the
/// `msgpack_gleam/timestamp` module for convenient timestamp handling:
///
/// ```gleam
/// import msgpack_gleam.{pack, unpack_exact}
/// import msgpack_gleam/timestamp
///
/// // Create and encode a timestamp
/// let ts = timestamp.from_unix_seconds(1234567890)
/// let value = timestamp.encode(ts)
/// let assert Ok(data) = pack(value)
///
/// // Decode it back
/// let assert Ok(decoded_value) = unpack_exact(data)
/// let assert Ok(decoded_ts) = timestamp.decode(decoded_value)
/// ```
import msgpack_gleam/decode
import msgpack_gleam/encode
import msgpack_gleam/error.{type DecodeError, type EncodeError}
import msgpack_gleam/value.{type Value}

/// Encode a MessagePack Value to binary data.
///
/// Returns the canonical (smallest) encoding for each value. This follows
/// the MessagePack specification recommendation for deterministic encoding.
///
/// ## Example
///
/// ```gleam
/// import msgpack_gleam.{pack}
/// import msgpack_gleam/value.{Integer}
///
/// let assert Ok(data) = pack(Integer(42))
/// // data == <<0x2a>> (fixint encoding)
/// ```
pub fn pack(value: Value) -> Result(BitArray, EncodeError) {
  encode.encode(value)
}

/// Decode MessagePack binary data to a Value.
///
/// Returns the decoded value and any remaining bytes. This is useful when
/// decoding a stream of MessagePack values.
///
/// Use `unpack_exact` if you want to ensure no trailing bytes remain.
///
/// ## Example
///
/// ```gleam
/// import msgpack_gleam.{unpack}
/// import msgpack_gleam/value.{Integer}
///
/// let assert Ok(#(value, rest)) = unpack(<<0x2a, 0xff>>)
/// // value == Integer(42)
/// // rest == <<0xff>> (remaining bytes)
/// ```
pub fn unpack(data: BitArray) -> Result(#(Value, BitArray), DecodeError) {
  decode.decode(data)
}

/// Decode exactly one MessagePack value, ensuring no trailing bytes.
///
/// Returns an error if there are bytes remaining after the value.
///
/// ## Example
///
/// ```gleam
/// import msgpack_gleam.{unpack_exact}
/// import msgpack_gleam/value.{Integer}
///
/// let assert Ok(value) = unpack_exact(<<0x2a>>)
/// // value == Integer(42)
///
/// // Returns error with trailing bytes
/// let assert Error(_) = unpack_exact(<<0x2a, 0xff>>)
/// ```
pub fn unpack_exact(data: BitArray) -> Result(Value, DecodeError) {
  decode.decode_exact(data)
}

/// Re-export Value type for convenience
pub type MsgPackValue =
  Value

/// Re-export encode error type
pub type PackError =
  EncodeError

/// Re-export decode error type
pub type UnpackError =
  DecodeError
