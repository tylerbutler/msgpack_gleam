import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/list
import gleam/result
import msgpack_gleam/error.{type EncodeError}
import msgpack_gleam/value.{type Value}

/// Encode a MessagePack Value to binary data.
/// Returns the canonical (smallest) encoding for each value.
pub fn encode(value: Value) -> Result(BitArray, EncodeError) {
  encode_value(value)
  |> result.map(bytes_tree.to_bit_array)
}

fn encode_value(value: Value) -> Result(BytesTree, EncodeError) {
  case value {
    value.Nil -> Ok(encode_nil())
    value.Boolean(b) -> Ok(encode_bool(b))
    value.Integer(n) -> encode_int(n)
    value.Float(f) -> Ok(encode_float(f))
    value.String(s) -> encode_string(s)
    value.Binary(data) -> encode_binary(data)
    value.Array(items) -> encode_array(items)
    value.Map(pairs) -> encode_map(pairs)
    value.Extension(type_code, data) -> encode_extension(type_code, data)
  }
}

// ============================================================================
// Nil (0xc0)
// ============================================================================

fn encode_nil() -> BytesTree {
  bytes_tree.from_bit_array(<<0xc0>>)
}

// ============================================================================
// Boolean (0xc2 = false, 0xc3 = true)
// ============================================================================

fn encode_bool(b: Bool) -> BytesTree {
  case b {
    False -> bytes_tree.from_bit_array(<<0xc2>>)
    True -> bytes_tree.from_bit_array(<<0xc3>>)
  }
}

// ============================================================================
// Integer encoding
// Canonical encoding uses the smallest representation possible
// ============================================================================

fn encode_int(n: Int) -> Result(BytesTree, EncodeError) {
  case n {
    // Positive fixint: 0x00-0x7f (0-127)
    _ if n >= 0 && n <= 127 -> Ok(bytes_tree.from_bit_array(<<n:8>>))

    // Negative fixint: 0xe0-0xff (-32 to -1)
    _ if n >= -32 && n < 0 -> {
      // Two's complement: -1 = 0xff, -32 = 0xe0
      let byte = n + 256
      Ok(bytes_tree.from_bit_array(<<byte:8>>))
    }

    // uint8: 0xcc (128-255)
    _ if n >= 128 && n <= 255 -> Ok(bytes_tree.from_bit_array(<<0xcc, n:8>>))

    // int8: 0xd0 (-128 to -33)
    _ if n >= -128 && n < -32 -> {
      let byte = n + 256
      Ok(bytes_tree.from_bit_array(<<0xd0, byte:8>>))
    }

    // uint16: 0xcd (256-65535)
    _ if n >= 256 && n <= 65_535 ->
      Ok(bytes_tree.from_bit_array(<<0xcd, n:16>>))

    // int16: 0xd1 (-32768 to -129)
    _ if n >= -32_768 && n < -128 -> {
      let bytes = n + 65_536
      Ok(bytes_tree.from_bit_array(<<0xd1, bytes:16>>))
    }

    // uint32: 0xce (65536 to 4294967295)
    _ if n >= 65_536 && n <= 4_294_967_295 ->
      Ok(bytes_tree.from_bit_array(<<0xce, n:32>>))

    // int32: 0xd2 (-2147483648 to -32769)
    _ if n >= -2_147_483_648 && n < -32_768 -> {
      let bytes = n + 4_294_967_296
      Ok(bytes_tree.from_bit_array(<<0xd2, bytes:32>>))
    }

    // uint64: 0xcf (4294967296 to 18446744073709551615)
    _ if n >= 4_294_967_296 && n <= 18_446_744_073_709_551_615 ->
      Ok(bytes_tree.from_bit_array(<<0xcf, n:64>>))

    // int64: 0xd3 (large negative numbers)
    _ if n >= -9_223_372_036_854_775_808 && n < -2_147_483_648 -> {
      // For negative numbers, convert to two's complement
      // n is already negative, adding 2^64 gives the unsigned representation
      let unsigned = n + 18_446_744_073_709_551_616
      Ok(bytes_tree.from_bit_array(<<0xd3, unsigned:64>>))
    }

    // Out of range
    _ -> Error(error.IntegerTooLarge(n))
  }
}

// ============================================================================
// Float encoding (always uses float64 for precision)
// ============================================================================

fn encode_float(f: Float) -> BytesTree {
  // Always use float64 (0xcb) for precision
  bytes_tree.from_bit_array(<<0xcb, f:float>>)
}

// ============================================================================
// String encoding
// ============================================================================

fn encode_string(s: String) -> Result(BytesTree, EncodeError) {
  let bytes = bit_array.from_string(s)
  let len = bit_array.byte_size(bytes)

  case len {
    // fixstr: 0xa0-0xbf (0-31 bytes)
    _ if len <= 31 -> {
      let header = 0xa0 + len
      Ok(
        bytes_tree.new()
        |> bytes_tree.append(<<header:8>>)
        |> bytes_tree.append(bytes),
      )
    }

    // str8: 0xd9 (32-255 bytes)
    _ if len <= 255 ->
      Ok(
        bytes_tree.new()
        |> bytes_tree.append(<<0xd9, len:8>>)
        |> bytes_tree.append(bytes),
      )

    // str16: 0xda (256-65535 bytes)
    _ if len <= 65_535 ->
      Ok(
        bytes_tree.new()
        |> bytes_tree.append(<<0xda, len:16>>)
        |> bytes_tree.append(bytes),
      )

    // str32: 0xdb (65536+ bytes)
    _ if len <= 4_294_967_295 ->
      Ok(
        bytes_tree.new()
        |> bytes_tree.append(<<0xdb, len:32>>)
        |> bytes_tree.append(bytes),
      )

    _ -> Error(error.StringTooLong(len))
  }
}

// ============================================================================
// Binary encoding
// ============================================================================

fn encode_binary(data: BitArray) -> Result(BytesTree, EncodeError) {
  let len = bit_array.byte_size(data)

  case len {
    // bin8: 0xc4 (0-255 bytes)
    _ if len <= 255 ->
      Ok(
        bytes_tree.new()
        |> bytes_tree.append(<<0xc4, len:8>>)
        |> bytes_tree.append(data),
      )

    // bin16: 0xc5 (256-65535 bytes)
    _ if len <= 65_535 ->
      Ok(
        bytes_tree.new()
        |> bytes_tree.append(<<0xc5, len:16>>)
        |> bytes_tree.append(data),
      )

    // bin32: 0xc6 (65536+ bytes)
    _ if len <= 4_294_967_295 ->
      Ok(
        bytes_tree.new()
        |> bytes_tree.append(<<0xc6, len:32>>)
        |> bytes_tree.append(data),
      )

    _ -> Error(error.BinaryTooLong(len))
  }
}

// ============================================================================
// Array encoding
// ============================================================================

fn encode_array(items: List(Value)) -> Result(BytesTree, EncodeError) {
  let len = list.length(items)

  use header <- result.try(case len {
    // fixarray: 0x90-0x9f (0-15 elements)
    _ if len <= 15 -> {
      let h = 0x90 + len
      Ok(bytes_tree.from_bit_array(<<h:8>>))
    }

    // array16: 0xdc (16-65535 elements)
    _ if len <= 65_535 -> Ok(bytes_tree.from_bit_array(<<0xdc, len:16>>))

    // array32: 0xdd (65536+ elements)
    _ if len <= 4_294_967_295 -> Ok(bytes_tree.from_bit_array(<<0xdd, len:32>>))

    _ -> Error(error.ArrayTooLong(len))
  })

  // Encode all items
  use encoded_items <- result.try(list.try_map(items, encode_value))

  Ok(list.fold(encoded_items, header, bytes_tree.append_tree))
}

// ============================================================================
// Map encoding
// ============================================================================

fn encode_map(pairs: List(#(Value, Value))) -> Result(BytesTree, EncodeError) {
  let len = list.length(pairs)

  use header <- result.try(case len {
    // fixmap: 0x80-0x8f (0-15 pairs)
    _ if len <= 15 -> {
      let h = 0x80 + len
      Ok(bytes_tree.from_bit_array(<<h:8>>))
    }

    // map16: 0xde (16-65535 pairs)
    _ if len <= 65_535 -> Ok(bytes_tree.from_bit_array(<<0xde, len:16>>))

    // map32: 0xdf (65536+ pairs)
    _ if len <= 4_294_967_295 -> Ok(bytes_tree.from_bit_array(<<0xdf, len:32>>))

    _ -> Error(error.MapTooLong(len))
  })

  // Encode all pairs
  use encoded_pairs <- result.try(
    list.try_map(pairs, fn(pair) {
      let #(key, val) = pair
      use encoded_key <- result.try(encode_value(key))
      use encoded_val <- result.try(encode_value(val))
      Ok(bytes_tree.append_tree(encoded_key, encoded_val))
    }),
  )

  Ok(list.fold(encoded_pairs, header, bytes_tree.append_tree))
}

// ============================================================================
// Extension type encoding
// ============================================================================

fn encode_extension(
  type_code: Int,
  data: BitArray,
) -> Result(BytesTree, EncodeError) {
  // Validate type code (-128 to 127)
  case type_code >= -128 && type_code <= 127 {
    False -> Error(error.InvalidExtensionTypeCode(type_code))
    True -> {
      let len = bit_array.byte_size(data)
      // Convert type_code to unsigned byte
      let tc = case type_code < 0 {
        True -> type_code + 256
        False -> type_code
      }

      case len {
        // fixext1: 0xd4
        1 ->
          Ok(
            bytes_tree.new()
            |> bytes_tree.append(<<0xd4, tc:8>>)
            |> bytes_tree.append(data),
          )

        // fixext2: 0xd5
        2 ->
          Ok(
            bytes_tree.new()
            |> bytes_tree.append(<<0xd5, tc:8>>)
            |> bytes_tree.append(data),
          )

        // fixext4: 0xd6
        4 ->
          Ok(
            bytes_tree.new()
            |> bytes_tree.append(<<0xd6, tc:8>>)
            |> bytes_tree.append(data),
          )

        // fixext8: 0xd7
        8 ->
          Ok(
            bytes_tree.new()
            |> bytes_tree.append(<<0xd7, tc:8>>)
            |> bytes_tree.append(data),
          )

        // fixext16: 0xd8
        16 ->
          Ok(
            bytes_tree.new()
            |> bytes_tree.append(<<0xd8, tc:8>>)
            |> bytes_tree.append(data),
          )

        // ext8: 0xc7 (0-255 bytes, excluding fixext sizes)
        _ if len <= 255 ->
          Ok(
            bytes_tree.new()
            |> bytes_tree.append(<<0xc7, len:8, tc:8>>)
            |> bytes_tree.append(data),
          )

        // ext16: 0xc8 (256-65535 bytes)
        _ if len <= 65_535 ->
          Ok(
            bytes_tree.new()
            |> bytes_tree.append(<<0xc8, len:16, tc:8>>)
            |> bytes_tree.append(data),
          )

        // ext32: 0xc9 (65536+ bytes)
        _ if len <= 4_294_967_295 ->
          Ok(
            bytes_tree.new()
            |> bytes_tree.append(<<0xc9, len:32, tc:8>>)
            |> bytes_tree.append(data),
          )

        _ -> Error(error.ExtensionDataTooLong(len))
      }
    }
  }
}
