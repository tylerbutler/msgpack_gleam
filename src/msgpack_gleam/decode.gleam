import gleam/bit_array
import gleam/list
import gleam/result
import msgpack_gleam/error.{type DecodeError}
import msgpack_gleam/value.{type Value}

/// Decode MessagePack binary data to a Value.
/// Returns the decoded value and any remaining bytes.
pub fn decode(data: BitArray) -> Result(#(Value, BitArray), DecodeError) {
  case data {
    <<>> -> Error(error.UnexpectedEof)

    // Nil (0xc0)
    <<0xc0, rest:bits>> -> Ok(#(value.Nil, rest))

    // Boolean
    <<0xc2, rest:bits>> -> Ok(#(value.Boolean(False), rest))
    <<0xc3, rest:bits>> -> Ok(#(value.Boolean(True), rest))

    // Positive fixint (0x00-0x7f)
    <<n:8, rest:bits>> if n <= 0x7f -> Ok(#(value.Integer(n), rest))

    // Negative fixint (0xe0-0xff)
    <<n:8, rest:bits>> if n >= 0xe0 -> {
      // Convert to signed: 0xe0 = -32, 0xff = -1
      let signed = n - 256
      Ok(#(value.Integer(signed), rest))
    }

    // uint8 (0xcc)
    <<0xcc, n:8, rest:bits>> -> Ok(#(value.Integer(n), rest))

    // uint16 (0xcd)
    <<0xcd, n:16, rest:bits>> -> Ok(#(value.Integer(n), rest))

    // uint32 (0xce)
    <<0xce, n:32, rest:bits>> -> Ok(#(value.Integer(n), rest))

    // uint64 (0xcf)
    <<0xcf, n:64-unsigned, rest:bits>> -> Ok(#(value.Integer(n), rest))

    // int8 (0xd0)
    <<0xd0, n:8-signed, rest:bits>> -> Ok(#(value.Integer(n), rest))

    // int16 (0xd1)
    <<0xd1, n:16-signed, rest:bits>> -> Ok(#(value.Integer(n), rest))

    // int32 (0xd2)
    <<0xd2, n:32-signed, rest:bits>> -> Ok(#(value.Integer(n), rest))

    // int64 (0xd3)
    <<0xd3, n:64-signed, rest:bits>> -> Ok(#(value.Integer(n), rest))

    // float32 (0xca)
    <<0xca, f:32-float, rest:bits>> -> Ok(#(value.Float(f), rest))

    // float64 (0xcb)
    <<0xcb, f:64-float, rest:bits>> -> Ok(#(value.Float(f), rest))

    // fixstr (0xa0-0xbf)
    <<header:8, rest:bits>> if header >= 0xa0 && header <= 0xbf -> {
      let len = header - 0xa0
      decode_string(rest, len)
    }

    // str8 (0xd9)
    <<0xd9, len:8, rest:bits>> -> decode_string(rest, len)

    // str16 (0xda)
    <<0xda, len:16, rest:bits>> -> decode_string(rest, len)

    // str32 (0xdb)
    <<0xdb, len:32, rest:bits>> -> decode_string(rest, len)

    // bin8 (0xc4)
    <<0xc4, len:8, rest:bits>> -> decode_binary(rest, len)

    // bin16 (0xc5)
    <<0xc5, len:16, rest:bits>> -> decode_binary(rest, len)

    // bin32 (0xc6)
    <<0xc6, len:32, rest:bits>> -> decode_binary(rest, len)

    // fixarray (0x90-0x9f)
    <<header:8, rest:bits>> if header >= 0x90 && header <= 0x9f -> {
      let len = header - 0x90
      decode_array(rest, len)
    }

    // array16 (0xdc)
    <<0xdc, len:16, rest:bits>> -> decode_array(rest, len)

    // array32 (0xdd)
    <<0xdd, len:32, rest:bits>> -> decode_array(rest, len)

    // fixmap (0x80-0x8f)
    <<header:8, rest:bits>> if header >= 0x80 && header <= 0x8f -> {
      let len = header - 0x80
      decode_map(rest, len)
    }

    // map16 (0xde)
    <<0xde, len:16, rest:bits>> -> decode_map(rest, len)

    // map32 (0xdf)
    <<0xdf, len:32, rest:bits>> -> decode_map(rest, len)

    // fixext1 (0xd4)
    <<0xd4, tc:8, data:bits-size(8), rest:bits>> ->
      Ok(#(value.Extension(signed_type_code(tc), <<data:bits>>), rest))

    // fixext2 (0xd5)
    <<0xd5, tc:8, data:bits-size(16), rest:bits>> ->
      Ok(#(value.Extension(signed_type_code(tc), <<data:bits>>), rest))

    // fixext4 (0xd6)
    <<0xd6, tc:8, data:bits-size(32), rest:bits>> ->
      Ok(#(value.Extension(signed_type_code(tc), <<data:bits>>), rest))

    // fixext8 (0xd7)
    <<0xd7, tc:8, data:bits-size(64), rest:bits>> ->
      Ok(#(value.Extension(signed_type_code(tc), <<data:bits>>), rest))

    // fixext16 (0xd8)
    <<0xd8, tc:8, data:bits-size(128), rest:bits>> ->
      Ok(#(value.Extension(signed_type_code(tc), <<data:bits>>), rest))

    // ext8 (0xc7)
    <<0xc7, len:8, tc:8, rest:bits>> -> decode_extension(rest, len, tc)

    // ext16 (0xc8)
    <<0xc8, len:16, tc:8, rest:bits>> -> decode_extension(rest, len, tc)

    // ext32 (0xc9)
    <<0xc9, len:32, tc:8, rest:bits>> -> decode_extension(rest, len, tc)

    // Reserved formats (0xc1)
    <<0xc1, _:bits>> -> Error(error.ReservedFormat(0xc1))

    // Invalid/incomplete format
    <<byte:8, _:bits>> -> Error(error.InvalidFormat(byte))

    // Catch-all for non-byte-aligned or other edge cases
    _ -> Error(error.UnexpectedEof)
  }
}

/// Decode exactly one value, ensuring no trailing bytes
pub fn decode_exact(data: BitArray) -> Result(Value, DecodeError) {
  use #(value, rest) <- result.try(decode(data))
  case rest {
    <<>> -> Ok(value)
    _ -> Error(error.TrailingBytes(bit_array.byte_size(rest)))
  }
}

// ============================================================================
// String decoding
// ============================================================================

fn decode_string(
  data: BitArray,
  len: Int,
) -> Result(#(Value, BitArray), DecodeError) {
  let bits_len = len * 8
  case data {
    <<str_bytes:bits-size(bits_len), rest:bits>> -> {
      case bit_array.to_string(<<str_bytes:bits>>) {
        Ok(s) -> Ok(#(value.String(s), rest))
        Error(_) -> Error(error.InvalidUtf8)
      }
    }
    _ -> Error(error.UnexpectedEof)
  }
}

// ============================================================================
// Binary decoding
// ============================================================================

fn decode_binary(
  data: BitArray,
  len: Int,
) -> Result(#(Value, BitArray), DecodeError) {
  let bits_len = len * 8
  case data {
    <<bin_bytes:bits-size(bits_len), rest:bits>> ->
      Ok(#(value.Binary(<<bin_bytes:bits>>), rest))
    _ -> Error(error.UnexpectedEof)
  }
}

// ============================================================================
// Array decoding
// ============================================================================

fn decode_array(
  data: BitArray,
  len: Int,
) -> Result(#(Value, BitArray), DecodeError) {
  decode_array_items(data, len, [])
}

fn decode_array_items(
  data: BitArray,
  remaining: Int,
  acc: List(Value),
) -> Result(#(Value, BitArray), DecodeError) {
  case remaining {
    0 -> Ok(#(value.Array(list.reverse(acc)), data))
    _ -> {
      use #(item, rest) <- result.try(decode(data))
      decode_array_items(rest, remaining - 1, [item, ..acc])
    }
  }
}

// ============================================================================
// Map decoding
// ============================================================================

fn decode_map(
  data: BitArray,
  len: Int,
) -> Result(#(Value, BitArray), DecodeError) {
  decode_map_pairs(data, len, [])
}

fn decode_map_pairs(
  data: BitArray,
  remaining: Int,
  acc: List(#(Value, Value)),
) -> Result(#(Value, BitArray), DecodeError) {
  case remaining {
    0 -> Ok(#(value.Map(list.reverse(acc)), data))
    _ -> {
      use #(key, rest1) <- result.try(decode(data))
      use #(val, rest2) <- result.try(decode(rest1))
      decode_map_pairs(rest2, remaining - 1, [#(key, val), ..acc])
    }
  }
}

// ============================================================================
// Extension type decoding
// ============================================================================

fn decode_extension(
  data: BitArray,
  len: Int,
  type_code: Int,
) -> Result(#(Value, BitArray), DecodeError) {
  let bits_len = len * 8
  case data {
    <<ext_bytes:bits-size(bits_len), rest:bits>> ->
      Ok(#(
        value.Extension(signed_type_code(type_code), <<ext_bytes:bits>>),
        rest,
      ))
    _ -> Error(error.UnexpectedEof)
  }
}

/// Convert unsigned type code byte to signed (-128 to 127)
fn signed_type_code(tc: Int) -> Int {
  case tc > 127 {
    True -> tc - 256
    False -> tc
  }
}
