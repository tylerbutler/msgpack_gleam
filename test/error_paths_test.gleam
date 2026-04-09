import msgpack_gleam.{pack, unpack, unpack_exact}
import msgpack_gleam/error
import msgpack_gleam/value.{Extension}
import startest/expect

// ============================================================================
// UnexpectedEof — Empty Input
// ============================================================================

pub fn decode_empty_input_test() {
  unpack(<<>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

// ============================================================================
// UnexpectedEof — Truncated Numeric Types
// ============================================================================

pub fn decode_truncated_uint8_test() {
  // 0xcc requires 1 payload byte
  unpack(<<0xcc>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_uint16_test() {
  // 0xcd requires 2 payload bytes, provide 1
  unpack(<<0xcd, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_uint32_test() {
  // 0xce requires 4 payload bytes, provide 2
  unpack(<<0xce, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_uint64_test() {
  // 0xcf requires 8 payload bytes, provide 4
  unpack(<<0xcf, 0x00, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_int8_test() {
  // 0xd0 requires 1 payload byte
  unpack(<<0xd0>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_int16_test() {
  // 0xd1 requires 2 payload bytes, provide 1
  unpack(<<0xd1, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_int32_test() {
  // 0xd2 requires 4 payload bytes, provide 1
  unpack(<<0xd2, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_int64_test() {
  // 0xd3 requires 8 payload bytes, provide 3
  unpack(<<0xd3, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_float32_test() {
  // 0xca requires 4 payload bytes, provide 2
  unpack(<<0xca, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_float64_test() {
  // 0xcb requires 8 payload bytes, provide 3
  unpack(<<0xcb, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

// ============================================================================
// UnexpectedEof — Truncated String Formats
// ============================================================================

pub fn decode_truncated_fixstr_short_data_test() {
  // fixstr with length=3 (0xa3) but only 2 payload bytes
  unpack(<<0xa3, 0x61, 0x62>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_str8_no_length_test() {
  // 0xd9 requires 1-byte length, provide 0
  unpack(<<0xd9>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_str8_short_data_test() {
  // str8 with length=5 but only 2 payload bytes
  unpack(<<0xd9, 0x05, 0x61, 0x62>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_str16_no_length_test() {
  // 0xda requires 2-byte length, provide 1
  unpack(<<0xda, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_str16_short_data_test() {
  // str16 with length=3 but only 1 payload byte
  unpack(<<0xda, 0x00, 0x03, 0x61>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_str32_no_length_test() {
  // 0xdb requires 4-byte length, provide 2
  unpack(<<0xdb, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_str32_short_data_test() {
  // str32 with length=2 but only 1 payload byte
  unpack(<<0xdb, 0x00, 0x00, 0x00, 0x02, 0x61>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

// ============================================================================
// UnexpectedEof — Truncated Binary Formats
// ============================================================================

pub fn decode_truncated_bin8_no_length_test() {
  // 0xc4 requires 1-byte length
  unpack(<<0xc4>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_bin8_short_data_test() {
  // bin8 with length=3 but only 1 payload byte
  unpack(<<0xc4, 0x03, 0xaa>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_bin16_no_length_test() {
  // 0xc5 requires 2-byte length, provide 1
  unpack(<<0xc5, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_bin16_short_data_test() {
  // bin16 with length=2 but only 1 payload byte
  unpack(<<0xc5, 0x00, 0x02, 0xaa>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_bin32_no_length_test() {
  // 0xc6 requires 4-byte length, provide 2
  unpack(<<0xc6, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_bin32_short_data_test() {
  // bin32 with length=2 but only 1 payload byte
  unpack(<<0xc6, 0x00, 0x00, 0x00, 0x02, 0xaa>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

// ============================================================================
// UnexpectedEof — Truncated Array/Map Formats
// ============================================================================

pub fn decode_truncated_fixarray_short_data_test() {
  // fixarray with 2 elements (0x92) but only 1 element follows
  unpack(<<0x92, 0x01>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_array16_no_length_test() {
  // 0xdc requires 2-byte length, provide 1
  unpack(<<0xdc, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_array16_short_data_test() {
  // array16 with length=2 but only 1 element
  unpack(<<0xdc, 0x00, 0x02, 0x01>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_array32_no_length_test() {
  // 0xdd requires 4-byte length, provide 2
  unpack(<<0xdd, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_array32_short_data_test() {
  // array32 with length=1 but no elements follow
  unpack(<<0xdd, 0x00, 0x00, 0x00, 0x01>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_fixmap_short_data_test() {
  // fixmap with 1 entry (0x81), key present but no value
  unpack(<<0x81, 0x01>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_map16_no_length_test() {
  // 0xde requires 2-byte length, provide 1
  unpack(<<0xde, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_map16_short_data_test() {
  // map16 with 1 pair, key present but no value
  unpack(<<0xde, 0x00, 0x01, 0x01>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_map32_no_length_test() {
  // 0xdf requires 4-byte length, provide 2
  unpack(<<0xdf, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_map32_short_data_test() {
  // map32 with 1 entry but no key-value pairs follow
  unpack(<<0xdf, 0x00, 0x00, 0x00, 0x01>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

// ============================================================================
// UnexpectedEof — Truncated Extension Formats
// ============================================================================

pub fn decode_truncated_fixext1_test() {
  // 0xd4 requires type_code(1) + 1 byte data; provide only type code
  unpack(<<0xd4, 0x01>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_fixext2_test() {
  // 0xd5 requires type_code(1) + 2 bytes data; provide type_code + 1 byte
  unpack(<<0xd5, 0x01, 0xaa>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_fixext4_test() {
  // 0xd6 requires type_code(1) + 4 bytes data; provide type_code + 2 bytes
  unpack(<<0xd6, 0x01, 0xaa, 0xbb>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_fixext8_test() {
  // 0xd7 requires type_code(1) + 8 bytes data; provide type_code + 4 bytes
  unpack(<<0xd7, 0x01, 0xaa, 0xbb, 0xcc, 0xdd>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_fixext16_test() {
  // 0xd8 requires type_code(1) + 16 bytes data; provide type_code + 8 bytes
  unpack(<<0xd8, 0x01, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_ext8_no_header_test() {
  // 0xc7 requires length(1) + type_code(1); provide only length
  unpack(<<0xc7, 0x02>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_ext8_short_data_test() {
  // ext8, length=3, type_code=1, but only 1 byte of data
  unpack(<<0xc7, 0x03, 0x01, 0xaa>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_ext16_no_header_test() {
  // 0xc8 requires length(2) + type_code(1); provide only partial length
  unpack(<<0xc8, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_ext16_short_data_test() {
  // ext16, length=2, type_code=1, but only 1 byte of data
  unpack(<<0xc8, 0x00, 0x02, 0x01, 0xaa>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_ext32_no_header_test() {
  // 0xc9 requires length(4) + type_code(1); provide only 3 bytes
  unpack(<<0xc9, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

pub fn decode_truncated_ext32_short_data_test() {
  // ext32, length=2, type_code=1, but only 1 byte of data
  unpack(<<0xc9, 0x00, 0x00, 0x00, 0x02, 0x01, 0xaa>>)
  |> expect.to_equal(Error(error.UnexpectedEof))
}

// ============================================================================
// UnsupportedFloat — NaN and Infinity
// ============================================================================

pub fn decode_float32_nan_test() {
  // float32 quiet NaN: 0xca 7fc00000
  unpack(<<0xca, 0x7f, 0xc0, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnsupportedFloat))
}

pub fn decode_float32_positive_infinity_test() {
  // float32 +Inf: 0xca 7f800000
  unpack(<<0xca, 0x7f, 0x80, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnsupportedFloat))
}

pub fn decode_float32_negative_infinity_test() {
  // float32 -Inf: 0xca ff800000
  unpack(<<0xca, 0xff, 0x80, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnsupportedFloat))
}

pub fn decode_float32_signaling_nan_test() {
  // float32 signaling NaN: exponent=0xFF, mantissa=1
  unpack(<<0xca, 0x7f, 0x80, 0x00, 0x01>>)
  |> expect.to_equal(Error(error.UnsupportedFloat))
}

pub fn decode_float64_nan_test() {
  // float64 quiet NaN: 0xcb 7ff8000000000000
  unpack(<<0xcb, 0x7f, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnsupportedFloat))
}

pub fn decode_float64_positive_infinity_test() {
  // float64 +Inf: 0xcb 7ff0000000000000
  unpack(<<0xcb, 0x7f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnsupportedFloat))
}

pub fn decode_float64_negative_infinity_test() {
  // float64 -Inf: 0xcb fff0000000000000
  unpack(<<0xcb, 0xff, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Error(error.UnsupportedFloat))
}

pub fn decode_float64_signaling_nan_test() {
  // float64 signaling NaN: exponent=0x7FF, mantissa=1
  unpack(<<0xcb, 0x7f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01>>)
  |> expect.to_equal(Error(error.UnsupportedFloat))
}

// ============================================================================
// PayloadTooLarge — Security Limits
// ============================================================================

pub fn decode_string_payload_too_large_test() {
  // str32 claiming 200,000,000 bytes (> 134,217,728 limit)
  unpack(<<0xdb, 0x0b, 0xeb, 0xc2, 0x00>>)
  |> expect.to_equal(Error(error.PayloadTooLarge(200_000_000)))
}

pub fn decode_binary_payload_too_large_test() {
  // bin32 claiming 200,000,000 bytes
  unpack(<<0xc6, 0x0b, 0xeb, 0xc2, 0x00>>)
  |> expect.to_equal(Error(error.PayloadTooLarge(200_000_000)))
}

pub fn decode_array_payload_too_large_test() {
  // array32 claiming 5,000,000 elements (> 4,194,304 limit)
  unpack(<<0xdd, 0x00, 0x4c, 0x4b, 0x40>>)
  |> expect.to_equal(Error(error.PayloadTooLarge(5_000_000)))
}

pub fn decode_map_payload_too_large_test() {
  // map32 claiming 5,000,000 entries
  unpack(<<0xdf, 0x00, 0x4c, 0x4b, 0x40>>)
  |> expect.to_equal(Error(error.PayloadTooLarge(5_000_000)))
}

pub fn decode_ext_payload_too_large_test() {
  // ext32 claiming 200,000,000 bytes, type_code=1
  unpack(<<0xc9, 0x0b, 0xeb, 0xc2, 0x00, 0x01>>)
  |> expect.to_equal(Error(error.PayloadTooLarge(200_000_000)))
}

pub fn decode_string_payload_just_over_limit_test() {
  // str32 claiming 134,217,729 (max + 1 = 0x08000001)
  unpack(<<0xdb, 0x08, 0x00, 0x00, 0x01>>)
  |> expect.to_equal(Error(error.PayloadTooLarge(134_217_729)))
}

pub fn decode_array_payload_just_over_limit_test() {
  // array32 claiming 4,194,305 (max + 1 = 0x00400001)
  unpack(<<0xdd, 0x00, 0x40, 0x00, 0x01>>)
  |> expect.to_equal(Error(error.PayloadTooLarge(4_194_305)))
}

// ============================================================================
// InvalidUtf8 — Non-fixstr String Formats
// ============================================================================

pub fn decode_invalid_utf8_str8_test() {
  // str8 with length=2, invalid UTF-8 bytes
  unpack(<<0xd9, 0x02, 0xff, 0xfe>>)
  |> expect.to_equal(Error(error.InvalidUtf8))
}

pub fn decode_invalid_utf8_str16_test() {
  // str16 with length=2, invalid UTF-8 bytes
  unpack(<<0xda, 0x00, 0x02, 0xff, 0xfe>>)
  |> expect.to_equal(Error(error.InvalidUtf8))
}

pub fn decode_invalid_utf8_str32_test() {
  // str32 with length=2, invalid UTF-8 bytes
  unpack(<<0xdb, 0x00, 0x00, 0x00, 0x02, 0xff, 0xfe>>)
  |> expect.to_equal(Error(error.InvalidUtf8))
}

// ============================================================================
// Extension Type Code Boundaries (Encode)
// ============================================================================

pub fn encode_extension_type_code_min_boundary_test() {
  // -128 is the minimum valid type code — should succeed
  let assert Ok(_) = pack(Extension(-128, <<0x01>>))
  Nil
}

pub fn encode_extension_type_code_max_boundary_test() {
  // 127 is the maximum valid type code — should succeed
  let assert Ok(_) = pack(Extension(127, <<0x01>>))
  Nil
}

pub fn encode_extension_type_code_large_positive_test() {
  pack(Extension(1000, <<0x01>>))
  |> expect.to_equal(Error(error.InvalidExtensionTypeCode(1000)))
}

pub fn encode_extension_type_code_large_negative_test() {
  pack(Extension(-1000, <<0x01>>))
  |> expect.to_equal(Error(error.InvalidExtensionTypeCode(-1000)))
}

// ============================================================================
// TrailingBytes — Additional Cases
// ============================================================================

pub fn decode_trailing_bytes_multiple_test() {
  // Nil (0xc0) followed by 3 trailing bytes
  unpack_exact(<<0xc0, 0x01, 0x02, 0x03>>)
  |> expect.to_equal(Error(error.TrailingBytes(3)))
}

pub fn decode_trailing_bytes_after_integer_test() {
  // Integer(1) followed by 5 trailing bytes
  unpack_exact(<<0x01, 0xaa, 0xbb, 0xcc, 0xdd, 0xee>>)
  |> expect.to_equal(Error(error.TrailingBytes(5)))
}

// ============================================================================
// ReservedFormat — Additional Cases
// ============================================================================

pub fn decode_reserved_format_with_trailing_data_test() {
  // 0xc1 followed by extra bytes — should still return ReservedFormat
  unpack(<<0xc1, 0x00, 0x01, 0x02>>)
  |> expect.to_equal(Error(error.ReservedFormat(0xc1)))
}

// ============================================================================
// format_encode_error Coverage
// ============================================================================

pub fn format_encode_error_binary_too_long_test() {
  error.format_encode_error(error.BinaryTooLong(5_000_000_000))
  |> expect.to_equal("Binary too long: 5000000000 bytes (max 4294967295)")
}

pub fn format_encode_error_array_too_long_test() {
  error.format_encode_error(error.ArrayTooLong(5_000_000_000))
  |> expect.to_equal("Array too long: 5000000000 elements (max 4294967295)")
}

pub fn format_encode_error_map_too_long_test() {
  error.format_encode_error(error.MapTooLong(5_000_000_000))
  |> expect.to_equal("Map too long: 5000000000 entries (max 4294967295)")
}

pub fn format_encode_error_extension_data_too_long_test() {
  error.format_encode_error(error.ExtensionDataTooLong(5_000_000_000))
  |> expect.to_equal(
    "Extension data too long: 5000000000 bytes (max 4294967295)",
  )
}

// ============================================================================
// format_decode_error Coverage
// ============================================================================

// NOTE: IntegerOverflow is defined in error.gleam but never produced by any
// decode path. BEAM integers are arbitrary-precision, so integer overflow
// cannot occur during MessagePack decoding. This test covers the format
// function only.
pub fn format_decode_error_integer_overflow_test() {
  error.format_decode_error(error.IntegerOverflow)
  |> expect.to_equal("Integer overflow")
}

pub fn format_decode_error_reserved_format_test() {
  error.format_decode_error(error.ReservedFormat(0xc1))
  |> expect.to_equal("Reserved format byte: 193")
}

pub fn format_decode_error_payload_too_large_test() {
  error.format_decode_error(error.PayloadTooLarge(200_000_000))
  |> expect.to_equal("Payload too large: 200000000 bytes or elements")
}
