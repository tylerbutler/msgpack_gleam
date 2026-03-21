import gleam/dict
import gleam/int
import gleam/list
import gleam/string
import msgpack_gleam.{pack, unpack, unpack_exact}
import msgpack_gleam/error
import msgpack_gleam/timestamp.{Timestamp}
import msgpack_gleam/value.{
  Array, Binary, Boolean, Extension, Float, Integer, Map, Nil, String,
}
import startest
import startest/expect
import test_helpers.{
  ArrayValue, BinaryValue, BoolValue, ExtValue, FloatValue, IntValue, MapValue,
  NilValue, StringValue, TestCase, TimestampValue, bits_to_hex, get_test_cases,
  hex_to_bits, load_test_suite,
}

pub fn main() {
  startest.run(startest.default_config())
}

// ============================================================================
// Test Suite Loading Tests
// ============================================================================

pub fn load_test_suite_test() {
  let result = load_test_suite("test/test_data/msgpack-test-suite.json")
  expect.to_be_ok(result)

  let assert Ok(suite) = result
  // Verify all expected sections are present
  dict.size(suite) |> expect.to_equal(15)

  // Verify some specific sections
  get_test_cases(suite, "10.nil.yaml") |> list.length |> expect.to_equal(1)
  get_test_cases(suite, "11.bool.yaml") |> list.length |> expect.to_equal(2)
}

pub fn hex_to_bits_test() {
  // Simple single byte
  hex_to_bits("c0") |> expect.to_equal(Ok(<<0xc0>>))

  // Multiple bytes with dashes
  hex_to_bits("c4-01-01") |> expect.to_equal(Ok(<<0xc4, 0x01, 0x01>>))

  // Multiple bytes without dashes
  hex_to_bits("c40101") |> expect.to_equal(Ok(<<0xc4, 0x01, 0x01>>))
}

pub fn bits_to_hex_test() {
  bits_to_hex(<<0xc0>>) |> expect.to_equal("c0")
  bits_to_hex(<<0xc4, 0x01, 0x01>>) |> expect.to_equal("c40101")
}

// ============================================================================
// Test Suite Integration Tests
// ============================================================================

pub fn test_suite_nil_section_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "10.nil.yaml")

  // Should have 1 test case for nil
  list.length(cases) |> expect.to_equal(1)

  // First case should be NilValue with encoding c0
  let assert [TestCase(value: NilValue, msgpack: encodings)] = cases
  list.first(encodings) |> expect.to_equal(Ok(<<0xc0>>))
}

pub fn test_suite_bool_section_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "11.bool.yaml")

  // Should have 2 test cases (false and true)
  list.length(cases) |> expect.to_equal(2)

  // Verify false case
  let assert [TestCase(value: BoolValue(False), msgpack: false_encodings), ..] =
    cases
  list.first(false_encodings) |> expect.to_equal(Ok(<<0xc2>>))
}

pub fn test_suite_positive_int_section_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "20.number-positive.yaml")

  // Should have multiple test cases
  { cases != [] } |> expect.to_be_true

  // First case should be 0
  let assert [TestCase(value: IntValue(0), msgpack: _), ..] = cases
  Nil
}

pub fn test_suite_string_section_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "30.string-ascii.yaml")

  // Should have test cases
  { cases != [] } |> expect.to_be_true

  // First case should be empty string
  let assert [TestCase(value: StringValue(""), msgpack: _), ..] = cases
  Nil
}

// ============================================================================
// Nil Encoding/Decoding Tests
// ============================================================================

pub fn encode_nil_test() {
  pack(Nil) |> expect.to_equal(Ok(<<0xc0>>))
}

pub fn decode_nil_test() {
  unpack(<<0xc0>>) |> expect.to_equal(Ok(#(Nil, <<>>)))
  unpack_exact(<<0xc0>>) |> expect.to_equal(Ok(Nil))
}

// ============================================================================
// Boolean Encoding/Decoding Tests
// ============================================================================

pub fn encode_bool_test() {
  pack(Boolean(False)) |> expect.to_equal(Ok(<<0xc2>>))
  pack(Boolean(True)) |> expect.to_equal(Ok(<<0xc3>>))
}

pub fn decode_bool_test() {
  unpack(<<0xc2>>) |> expect.to_equal(Ok(#(Boolean(False), <<>>)))
  unpack(<<0xc3>>) |> expect.to_equal(Ok(#(Boolean(True), <<>>)))
}

// ============================================================================
// Integer Encoding/Decoding Tests
// ============================================================================

pub fn encode_positive_fixint_test() {
  // 0-127 should use fixint (single byte)
  pack(Integer(0)) |> expect.to_equal(Ok(<<0x00>>))
  pack(Integer(1)) |> expect.to_equal(Ok(<<0x01>>))
  pack(Integer(127)) |> expect.to_equal(Ok(<<0x7f>>))
}

pub fn decode_positive_fixint_test() {
  unpack(<<0x00>>) |> expect.to_equal(Ok(#(Integer(0), <<>>)))
  unpack(<<0x01>>) |> expect.to_equal(Ok(#(Integer(1), <<>>)))
  unpack(<<0x7f>>) |> expect.to_equal(Ok(#(Integer(127), <<>>)))
}

pub fn encode_negative_fixint_test() {
  // -32 to -1 should use negative fixint
  pack(Integer(-1)) |> expect.to_equal(Ok(<<0xff>>))
  pack(Integer(-32)) |> expect.to_equal(Ok(<<0xe0>>))
}

pub fn decode_negative_fixint_test() {
  unpack(<<0xff>>) |> expect.to_equal(Ok(#(Integer(-1), <<>>)))
  unpack(<<0xe0>>) |> expect.to_equal(Ok(#(Integer(-32), <<>>)))
}

pub fn encode_uint8_test() {
  // 128-255 should use uint8
  pack(Integer(128)) |> expect.to_equal(Ok(<<0xcc, 128>>))
  pack(Integer(255)) |> expect.to_equal(Ok(<<0xcc, 255>>))
}

pub fn decode_uint8_test() {
  unpack(<<0xcc, 128>>) |> expect.to_equal(Ok(#(Integer(128), <<>>)))
  unpack(<<0xcc, 255>>) |> expect.to_equal(Ok(#(Integer(255), <<>>)))
}

pub fn encode_int8_test() {
  // -128 to -33 should use int8
  pack(Integer(-33)) |> expect.to_equal(Ok(<<0xd0, 0xdf>>))
  pack(Integer(-128)) |> expect.to_equal(Ok(<<0xd0, 0x80>>))
}

pub fn decode_int8_test() {
  unpack(<<0xd0, 0xdf>>) |> expect.to_equal(Ok(#(Integer(-33), <<>>)))
  unpack(<<0xd0, 0x80>>) |> expect.to_equal(Ok(#(Integer(-128), <<>>)))
}

pub fn encode_uint16_test() {
  pack(Integer(256)) |> expect.to_equal(Ok(<<0xcd, 0x01, 0x00>>))
  pack(Integer(65_535)) |> expect.to_equal(Ok(<<0xcd, 0xff, 0xff>>))
}

pub fn decode_uint16_test() {
  unpack(<<0xcd, 0x01, 0x00>>) |> expect.to_equal(Ok(#(Integer(256), <<>>)))
  unpack(<<0xcd, 0xff, 0xff>>) |> expect.to_equal(Ok(#(Integer(65_535), <<>>)))
}

pub fn encode_int16_test() {
  pack(Integer(-129)) |> expect.to_equal(Ok(<<0xd1, 0xff, 0x7f>>))
  pack(Integer(-32_768)) |> expect.to_equal(Ok(<<0xd1, 0x80, 0x00>>))
}

pub fn decode_int16_test() {
  unpack(<<0xd1, 0xff, 0x7f>>) |> expect.to_equal(Ok(#(Integer(-129), <<>>)))
  unpack(<<0xd1, 0x80, 0x00>>) |> expect.to_equal(Ok(#(Integer(-32_768), <<>>)))
}

pub fn encode_uint32_test() {
  pack(Integer(65_536)) |> expect.to_equal(Ok(<<0xce, 0x00, 0x01, 0x00, 0x00>>))
  pack(Integer(4_294_967_295))
  |> expect.to_equal(Ok(<<0xce, 0xff, 0xff, 0xff, 0xff>>))
}

pub fn decode_uint32_test() {
  unpack(<<0xce, 0x00, 0x01, 0x00, 0x00>>)
  |> expect.to_equal(Ok(#(Integer(65_536), <<>>)))
  unpack(<<0xce, 0xff, 0xff, 0xff, 0xff>>)
  |> expect.to_equal(Ok(#(Integer(4_294_967_295), <<>>)))
}

pub fn encode_uint64_test() {
  pack(Integer(4_294_967_296))
  |> expect.to_equal(
    Ok(<<0xcf, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00>>),
  )
}

pub fn decode_uint64_test() {
  unpack(<<0xcf, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Ok(#(Integer(4_294_967_296), <<>>)))
}

pub fn encode_uint64_large_test() {
  // Test value in upper half of uint64 range (above max signed int64)
  // 2^63 = 9_223_372_036_854_775_808
  let large_value = 9_223_372_036_854_775_808
  pack(Integer(large_value))
  |> expect.to_equal(
    Ok(<<0xcf, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>),
  )
}

pub fn decode_uint64_large_test() {
  // Decode 2^63
  unpack(<<0xcf, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Ok(#(Integer(9_223_372_036_854_775_808), <<>>)))
}

pub fn encode_uint64_max_test() {
  // Test maximum uint64 value: 2^64 - 1 = 18_446_744_073_709_551_615
  let max_uint64 = 18_446_744_073_709_551_615
  pack(Integer(max_uint64))
  |> expect.to_equal(
    Ok(<<0xcf, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff>>),
  )
}

pub fn decode_uint64_max_test() {
  // Decode max uint64
  unpack(<<0xcf, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff>>)
  |> expect.to_equal(Ok(#(Integer(18_446_744_073_709_551_615), <<>>)))
}

pub fn roundtrip_uint64_large_test() {
  // Round-trip test for values above max signed int64
  let test_values = [
    9_223_372_036_854_775_808,
    // 2^63
    10_000_000_000_000_000_000,
    // 10 quintillion
    18_446_744_073_709_551_615,
    // max uint64
  ]

  list.each(test_values, fn(n) {
    let value = Integer(n)
    let assert Ok(encoded) = pack(value)
    let assert Ok(decoded) = unpack_exact(encoded)
    decoded |> expect.to_equal(value)
  })
}

// ============================================================================
// Float Encoding/Decoding Tests
// ============================================================================

pub fn encode_float_test() {
  // Always encodes as float64
  let assert Ok(result) = pack(Float(1.0))
  // Check first byte is float64 marker
  let assert <<0xcb, _:bits>> = result
  Nil
}

pub fn decode_float32_test() {
  // 1.0 as float32: 0x3f800000
  unpack(<<0xca, 0x3f, 0x80, 0x00, 0x00>>)
  |> expect.to_equal(Ok(#(Float(1.0), <<>>)))
}

pub fn decode_float64_test() {
  // 1.0 as float64
  unpack(<<0xcb, 0x3f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Ok(#(Float(1.0), <<>>)))
}

// ============================================================================
// String Encoding/Decoding Tests
// ============================================================================

pub fn encode_fixstr_test() {
  // Empty string
  pack(String("")) |> expect.to_equal(Ok(<<0xa0>>))
  // "a" (1 char)
  pack(String("a")) |> expect.to_equal(Ok(<<0xa1, 0x61>>))
  // 31 chars (max fixstr)
  let s31 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let assert Ok(result) = pack(String(s31))
  let assert <<0xbf, _:bits>> = result
  Nil
}

pub fn decode_fixstr_test() {
  unpack(<<0xa0>>) |> expect.to_equal(Ok(#(String(""), <<>>)))
  unpack(<<0xa1, 0x61>>) |> expect.to_equal(Ok(#(String("a"), <<>>)))
}

pub fn encode_str8_test() {
  // 32 chars (min str8)
  let s32 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let assert Ok(result) = pack(String(s32))
  let assert <<0xd9, 32, _:bits>> = result
  Nil
}

pub fn decode_str8_test() {
  unpack(<<0xd9, 0x01, 0x61>>) |> expect.to_equal(Ok(#(String("a"), <<>>)))
}

// ============================================================================
// Binary Encoding/Decoding Tests
// ============================================================================

pub fn encode_bin8_test() {
  pack(Binary(<<>>)) |> expect.to_equal(Ok(<<0xc4, 0x00>>))
  pack(Binary(<<0x01>>)) |> expect.to_equal(Ok(<<0xc4, 0x01, 0x01>>))
}

pub fn decode_bin8_test() {
  unpack(<<0xc4, 0x00>>) |> expect.to_equal(Ok(#(Binary(<<>>), <<>>)))
  unpack(<<0xc4, 0x01, 0x01>>) |> expect.to_equal(Ok(#(Binary(<<0x01>>), <<>>)))
}

// ============================================================================
// Array Encoding/Decoding Tests
// ============================================================================

pub fn encode_fixarray_test() {
  // Empty array
  pack(Array([])) |> expect.to_equal(Ok(<<0x90>>))
  // Array with one element
  pack(Array([Integer(1)])) |> expect.to_equal(Ok(<<0x91, 0x01>>))
}

pub fn decode_fixarray_test() {
  unpack(<<0x90>>) |> expect.to_equal(Ok(#(Array([]), <<>>)))
  unpack(<<0x91, 0x01>>) |> expect.to_equal(Ok(#(Array([Integer(1)]), <<>>)))
}

pub fn encode_nested_array_test() {
  pack(Array([Array([])]))
  |> expect.to_equal(Ok(<<0x91, 0x90>>))
}

pub fn decode_nested_array_test() {
  unpack(<<0x91, 0x90>>) |> expect.to_equal(Ok(#(Array([Array([])]), <<>>)))
}

// ============================================================================
// Map Encoding/Decoding Tests
// ============================================================================

pub fn encode_fixmap_test() {
  // Empty map
  pack(Map([])) |> expect.to_equal(Ok(<<0x80>>))
  // Map with one entry
  pack(Map([#(String("a"), Integer(1))]))
  |> expect.to_equal(Ok(<<0x81, 0xa1, 0x61, 0x01>>))
}

pub fn decode_fixmap_test() {
  unpack(<<0x80>>) |> expect.to_equal(Ok(#(Map([]), <<>>)))
  unpack(<<0x81, 0xa1, 0x61, 0x01>>)
  |> expect.to_equal(Ok(#(Map([#(String("a"), Integer(1))]), <<>>)))
}

// ============================================================================
// Extension Type Encoding/Decoding Tests
// ============================================================================

pub fn encode_fixext1_test() {
  pack(Extension(1, <<0xaa>>))
  |> expect.to_equal(Ok(<<0xd4, 0x01, 0xaa>>))
}

pub fn decode_fixext1_test() {
  unpack(<<0xd4, 0x01, 0xaa>>)
  |> expect.to_equal(Ok(#(Extension(1, <<0xaa>>), <<>>)))
}

pub fn encode_negative_ext_type_test() {
  // Timestamp extension is type -1
  pack(Extension(-1, <<0x00, 0x00, 0x00, 0x00>>))
  |> expect.to_equal(Ok(<<0xd6, 0xff, 0x00, 0x00, 0x00, 0x00>>))
}

pub fn decode_negative_ext_type_test() {
  unpack(<<0xd6, 0xff, 0x00, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Ok(#(Extension(-1, <<0x00, 0x00, 0x00, 0x00>>), <<>>)))
}

// ============================================================================
// Int32 Encoding/Decoding Tests (0xd2)
// ============================================================================

pub fn encode_int32_test() {
  // -32769 is just below int16 range, should use int32
  pack(Integer(-32_769))
  |> expect.to_equal(Ok(<<0xd2, 0xff, 0xff, 0x7f, 0xff>>))
  // Min int32
  pack(Integer(-2_147_483_648))
  |> expect.to_equal(Ok(<<0xd2, 0x80, 0x00, 0x00, 0x00>>))
}

pub fn decode_int32_test() {
  unpack(<<0xd2, 0xff, 0xff, 0x7f, 0xff>>)
  |> expect.to_equal(Ok(#(Integer(-32_769), <<>>)))
  unpack(<<0xd2, 0x80, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Ok(#(Integer(-2_147_483_648), <<>>)))
  // -65536
  unpack(<<0xd2, 0xff, 0xff, 0x00, 0x00>>)
  |> expect.to_equal(Ok(#(Integer(-65_536), <<>>)))
}

pub fn roundtrip_int32_test() {
  let test_values = [-32_769, -65_536, -100_000, -2_147_483_648]
  list.each(test_values, fn(n) {
    let value = Integer(n)
    let assert Ok(encoded) = pack(value)
    let assert Ok(decoded) = unpack_exact(encoded)
    decoded |> expect.to_equal(value)
  })
}

// ============================================================================
// Int64 Negative Encoding/Decoding Tests (0xd3)
// ============================================================================

pub fn encode_int64_negative_test() {
  // Just below int32 range
  pack(Integer(-2_147_483_649))
  |> expect.to_equal(
    Ok(<<0xd3, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff>>),
  )
}

pub fn decode_int64_negative_test() {
  unpack(<<0xd3, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff>>)
  |> expect.to_equal(Ok(#(Integer(-2_147_483_649), <<>>)))
  // Min int64
  unpack(<<0xd3, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
  |> expect.to_equal(Ok(#(Integer(-9_223_372_036_854_775_808), <<>>)))
}

pub fn roundtrip_int64_negative_test() {
  let test_values = [-2_147_483_649, -4_294_967_296, -9_223_372_036_854_775_808]
  list.each(test_values, fn(n) {
    let value = Integer(n)
    let assert Ok(encoded) = pack(value)
    let assert Ok(decoded) = unpack_exact(encoded)
    decoded |> expect.to_equal(value)
  })
}

// ============================================================================
// Bin16/Bin32 Encoding/Decoding Tests (0xc5, 0xc6)
// ============================================================================

pub fn encode_bin16_test() {
  // 256 bytes should use bin16
  let data = create_bytes(256)
  let assert Ok(encoded) = pack(Binary(data))
  let assert <<0xc5, 0x01, 0x00, _:bits>> = encoded
  Nil
}

pub fn decode_bin16_test() {
  // bin16 with 2 bytes of data
  unpack(<<0xc5, 0x00, 0x02, 0xaa, 0xbb>>)
  |> expect.to_equal(Ok(#(Binary(<<0xaa, 0xbb>>), <<>>)))
}

pub fn roundtrip_bin16_test() {
  let data = create_bytes(256)
  let assert Ok(encoded) = pack(Binary(data))
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> expect.to_equal(Binary(data))
}

// ============================================================================
// Str16 Encoding/Decoding Tests (0xda)
// ============================================================================

pub fn encode_str16_test() {
  // 256 chars should use str16
  let s = create_string(256)
  let assert Ok(encoded) = pack(String(s))
  let assert <<0xda, 0x01, 0x00, _:bits>> = encoded
  Nil
}

pub fn decode_str16_test() {
  // str16 with 2 chars
  unpack(<<0xda, 0x00, 0x02, 0x61, 0x62>>)
  |> expect.to_equal(Ok(#(String("ab"), <<>>)))
}

pub fn roundtrip_str16_test() {
  let s = create_string(256)
  let assert Ok(encoded) = pack(String(s))
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> expect.to_equal(String(s))
}

// ============================================================================
// Fixext2/Fixext16 Encoding/Decoding Tests (0xd5, 0xd8)
// ============================================================================

pub fn encode_fixext2_test() {
  pack(Extension(2, <<0xaa, 0xbb>>))
  |> expect.to_equal(Ok(<<0xd5, 0x02, 0xaa, 0xbb>>))
}

pub fn decode_fixext2_test() {
  unpack(<<0xd5, 0x02, 0xaa, 0xbb>>)
  |> expect.to_equal(Ok(#(Extension(2, <<0xaa, 0xbb>>), <<>>)))
}

pub fn encode_fixext16_test() {
  let data = <<
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d,
    0x0e, 0x0f, 0x10,
  >>
  let assert Ok(encoded) = pack(Extension(5, data))
  let assert <<0xd8, 0x05, _:bits>> = encoded
  Nil
}

pub fn decode_fixext16_test() {
  let data = <<
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d,
    0x0e, 0x0f, 0x10,
  >>
  unpack(<<0xd8, 0x05, data:bits>>)
  |> expect.to_equal(Ok(#(Extension(5, data), <<>>)))
}

// ============================================================================
// Ext8/Ext16/Ext32 Encoding/Decoding Tests (0xc7, 0xc8, 0xc9)
// ============================================================================

pub fn encode_ext8_test() {
  // 0 bytes (non-fixext size) should use ext8
  pack(Extension(1, <<>>))
  |> expect.to_equal(Ok(<<0xc7, 0x00, 0x01>>))
  // 3 bytes (non-fixext size) should use ext8
  pack(Extension(1, <<0xaa, 0xbb, 0xcc>>))
  |> expect.to_equal(Ok(<<0xc7, 0x03, 0x01, 0xaa, 0xbb, 0xcc>>))
}

pub fn decode_ext8_test() {
  unpack(<<0xc7, 0x00, 0x01>>)
  |> expect.to_equal(Ok(#(Extension(1, <<>>), <<>>)))
  unpack(<<0xc7, 0x03, 0x01, 0xaa, 0xbb, 0xcc>>)
  |> expect.to_equal(Ok(#(Extension(1, <<0xaa, 0xbb, 0xcc>>), <<>>)))
}

pub fn encode_ext16_test() {
  // 256 bytes should use ext16
  let data = create_bytes(256)
  let assert Ok(encoded) = pack(Extension(3, data))
  let assert <<0xc8, 0x01, 0x00, 0x03, _:bits>> = encoded
  Nil
}

pub fn decode_ext16_test() {
  // ext16 with 2 bytes of data
  unpack(<<0xc8, 0x00, 0x02, 0x03, 0xaa, 0xbb>>)
  |> expect.to_equal(Ok(#(Extension(3, <<0xaa, 0xbb>>), <<>>)))
}

// ============================================================================
// Array16 Encoding/Decoding Tests (0xdc)
// ============================================================================

pub fn encode_array16_test() {
  // 16 elements should use array16
  let items = list.repeat(Integer(1), 16)
  let assert Ok(encoded) = pack(Array(items))
  let assert <<0xdc, 0x00, 0x10, _:bits>> = encoded
  Nil
}

pub fn decode_array16_test() {
  // array16 with 16 fixint(1) elements
  let assert Ok(encoded) = pack(Array(list.repeat(Integer(1), 16)))
  let assert Ok(decoded) = unpack_exact(encoded)
  let assert Array(items) = decoded
  list.length(items) |> expect.to_equal(16)
}

pub fn roundtrip_array16_test() {
  let items = list.range(0, 19) |> list.map(Integer)
  let assert Ok(encoded) = pack(Array(items))
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> expect.to_equal(Array(items))
}

// ============================================================================
// Map16 Encoding/Decoding Tests (0xde)
// ============================================================================

pub fn encode_map16_test() {
  // 16 entries should use map16
  let pairs =
    list.range(0, 15)
    |> list.map(fn(i) { #(Integer(i), Integer(i)) })
  let assert Ok(encoded) = pack(Map(pairs))
  let assert <<0xde, 0x00, 0x10, _:bits>> = encoded
  Nil
}

pub fn decode_map16_test() {
  let pairs =
    list.range(0, 15)
    |> list.map(fn(i) { #(Integer(i), Integer(i)) })
  let assert Ok(encoded) = pack(Map(pairs))
  let assert Ok(decoded) = unpack_exact(encoded)
  let assert Map(decoded_pairs) = decoded
  list.length(decoded_pairs) |> expect.to_equal(16)
}

pub fn roundtrip_map16_test() {
  let pairs =
    list.range(0, 19)
    |> list.map(fn(i) { #(String("key" <> int.to_string(i)), Integer(i)) })
  let assert Ok(encoded) = pack(Map(pairs))
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> expect.to_equal(Map(pairs))
}

// ============================================================================
// Float Edge Cases
// ============================================================================

pub fn roundtrip_float_edge_cases_test() {
  let test_values = [0.0, -0.0, 1.5, -1.5, 3.14, -3.14, 1.0e100, 1.0e-100]
  list.each(test_values, fn(f) {
    let value = Float(f)
    let assert Ok(encoded) = pack(value)
    let assert Ok(decoded) = unpack_exact(encoded)
    decoded |> expect.to_equal(value)
  })
}

// ============================================================================
// Helpers for generating test data
// ============================================================================

fn create_bytes(n: Int) -> BitArray {
  create_bytes_acc(n, <<>>)
}

fn create_bytes_acc(n: Int, acc: BitArray) -> BitArray {
  case n {
    0 -> acc
    _ -> {
      let byte = n % 256
      create_bytes_acc(n - 1, <<acc:bits, byte:8>>)
    }
  }
}

fn create_string(n: Int) -> String {
  list.repeat("a", n) |> string.join("")
}

// ============================================================================
// Format Boundary Tests
// Verify the encoder picks the correct (smallest) format at each threshold
// ============================================================================

pub fn boundary_fixstr_to_str8_test() {
  // 31 bytes = max fixstr (0xa0-0xbf)
  let s31 = create_string(31)
  let assert Ok(encoded31) = pack(String(s31))
  let assert <<header31:8, _:bits>> = encoded31
  { header31 >= 0xa0 && header31 <= 0xbf } |> expect.to_be_true

  // 32 bytes = min str8 (0xd9)
  let s32 = create_string(32)
  let assert Ok(encoded32) = pack(String(s32))
  let assert <<0xd9, 32, _:bits>> = encoded32
  Nil
}

pub fn boundary_str8_to_str16_test() {
  // 255 bytes = max str8
  let s255 = create_string(255)
  let assert Ok(encoded255) = pack(String(s255))
  let assert <<0xd9, 255, _:bits>> = encoded255

  // 256 bytes = min str16
  let s256 = create_string(256)
  let assert Ok(encoded256) = pack(String(s256))
  let assert <<0xda, 0x01, 0x00, _:bits>> = encoded256
  Nil
}

pub fn boundary_bin8_to_bin16_test() {
  // 255 bytes = max bin8
  let b255 = create_bytes(255)
  let assert Ok(encoded255) = pack(Binary(b255))
  let assert <<0xc4, 255, _:bits>> = encoded255

  // 256 bytes = min bin16
  let b256 = create_bytes(256)
  let assert Ok(encoded256) = pack(Binary(b256))
  let assert <<0xc5, 0x01, 0x00, _:bits>> = encoded256
  Nil
}

pub fn boundary_fixarray_to_array16_test() {
  // 15 elements = max fixarray (0x90-0x9f)
  let a15 = list.repeat(Integer(0), 15)
  let assert Ok(encoded15) = pack(Array(a15))
  let assert <<0x9f, _:bits>> = encoded15

  // 16 elements = min array16 (0xdc)
  let a16 = list.repeat(Integer(0), 16)
  let assert Ok(encoded16) = pack(Array(a16))
  let assert <<0xdc, 0x00, 0x10, _:bits>> = encoded16
  Nil
}

pub fn boundary_fixmap_to_map16_test() {
  // 15 entries = max fixmap (0x80-0x8f)
  let m15 =
    list.range(0, 14)
    |> list.map(fn(i) { #(Integer(i), Integer(i)) })
  let assert Ok(encoded15) = pack(Map(m15))
  let assert <<0x8f, _:bits>> = encoded15

  // 16 entries = min map16 (0xde)
  let m16 =
    list.range(0, 15)
    |> list.map(fn(i) { #(Integer(i), Integer(i)) })
  let assert Ok(encoded16) = pack(Map(m16))
  let assert <<0xde, 0x00, 0x10, _:bits>> = encoded16
  Nil
}

pub fn boundary_negative_int_formats_test() {
  // -32 = max negative fixint
  let assert Ok(enc_m32) = pack(Integer(-32))
  let assert <<0xe0>> = enc_m32

  // -33 = min int8
  let assert Ok(enc_m33) = pack(Integer(-33))
  let assert <<0xd0, _:bits>> = enc_m33

  // -128 = max int8 (boundary)
  let assert Ok(enc_m128) = pack(Integer(-128))
  let assert <<0xd0, _:bits>> = enc_m128

  // -129 = min int16
  let assert Ok(enc_m129) = pack(Integer(-129))
  let assert <<0xd1, _:bits>> = enc_m129

  // -32768 = max int16 (boundary)
  let assert Ok(enc_m32768) = pack(Integer(-32_768))
  let assert <<0xd1, _:bits>> = enc_m32768

  // -32769 = min int32
  let assert Ok(enc_m32769) = pack(Integer(-32_769))
  let assert <<0xd2, _:bits>> = enc_m32769

  // -2147483648 = max int32 (boundary)
  let assert Ok(enc_min32) = pack(Integer(-2_147_483_648))
  let assert <<0xd2, _:bits>> = enc_min32

  // -2147483649 = min int64
  let assert Ok(enc_m2b) = pack(Integer(-2_147_483_649))
  let assert <<0xd3, _:bits>> = enc_m2b
  Nil
}

pub fn boundary_positive_int_formats_test() {
  // 127 = max fixint
  let assert Ok(enc127) = pack(Integer(127))
  let assert <<0x7f>> = enc127

  // 128 = min uint8
  let assert Ok(enc128) = pack(Integer(128))
  let assert <<0xcc, _:bits>> = enc128

  // 255 = max uint8
  let assert Ok(enc255) = pack(Integer(255))
  let assert <<0xcc, _:bits>> = enc255

  // 256 = min uint16
  let assert Ok(enc256) = pack(Integer(256))
  let assert <<0xcd, _:bits>> = enc256

  // 65535 = max uint16
  let assert Ok(enc65535) = pack(Integer(65_535))
  let assert <<0xcd, _:bits>> = enc65535

  // 65536 = min uint32
  let assert Ok(enc65536) = pack(Integer(65_536))
  let assert <<0xce, _:bits>> = enc65536

  // 4294967295 = max uint32
  let assert Ok(enc_max32) = pack(Integer(4_294_967_295))
  let assert <<0xce, _:bits>> = enc_max32

  // 4294967296 = min uint64
  let assert Ok(enc_min64) = pack(Integer(4_294_967_296))
  let assert <<0xcf, _:bits>> = enc_min64
  Nil
}

pub fn boundary_ext_sizes_test() {
  // 1 byte = fixext1 (0xd4)
  let assert Ok(e1) = pack(Extension(1, <<0xaa>>))
  let assert <<0xd4, _:bits>> = e1

  // 2 bytes = fixext2 (0xd5)
  let assert Ok(e2) = pack(Extension(1, <<0xaa, 0xbb>>))
  let assert <<0xd5, _:bits>> = e2

  // 3 bytes = ext8 (not a fixext size)
  let assert Ok(e3) = pack(Extension(1, <<0xaa, 0xbb, 0xcc>>))
  let assert <<0xc7, _:bits>> = e3

  // 4 bytes = fixext4 (0xd6)
  let assert Ok(e4) = pack(Extension(1, create_bytes(4)))
  let assert <<0xd6, _:bits>> = e4

  // 5 bytes = ext8 (not a fixext size)
  let assert Ok(e5) = pack(Extension(1, create_bytes(5)))
  let assert <<0xc7, _:bits>> = e5

  // 8 bytes = fixext8 (0xd7)
  let assert Ok(e8) = pack(Extension(1, create_bytes(8)))
  let assert <<0xd7, _:bits>> = e8

  // 16 bytes = fixext16 (0xd8)
  let assert Ok(e16) = pack(Extension(1, create_bytes(16)))
  let assert <<0xd8, _:bits>> = e16

  // 17 bytes = ext8
  let assert Ok(e17) = pack(Extension(1, create_bytes(17)))
  let assert <<0xc7, _:bits>> = e17
  Nil
}

// ============================================================================
// Round-trip Tests
// ============================================================================

pub fn roundtrip_nil_test() {
  let value = Nil
  let assert Ok(encoded) = pack(value)
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> expect.to_equal(value)
}

pub fn roundtrip_bool_test() {
  let assert Ok(encoded_true) = pack(Boolean(True))
  let assert Ok(decoded_true) = unpack_exact(encoded_true)
  decoded_true |> expect.to_equal(Boolean(True))

  let assert Ok(encoded_false) = pack(Boolean(False))
  let assert Ok(decoded_false) = unpack_exact(encoded_false)
  decoded_false |> expect.to_equal(Boolean(False))
}

pub fn roundtrip_integers_test() {
  let test_values = [
    0, 1, 127, 128, 255, 256, 65_535, 65_536, -1, -32, -33, -128, -129, -32_768,
    -32_769,
  ]

  list.each(test_values, fn(n) {
    let value = Integer(n)
    let assert Ok(encoded) = pack(value)
    let assert Ok(decoded) = unpack_exact(encoded)
    decoded |> expect.to_equal(value)
  })
}

pub fn roundtrip_string_test() {
  let test_values = ["", "a", "hello", "hello world", "こんにちは"]

  list.each(test_values, fn(s) {
    let value = String(s)
    let assert Ok(encoded) = pack(value)
    let assert Ok(decoded) = unpack_exact(encoded)
    decoded |> expect.to_equal(value)
  })
}

pub fn roundtrip_array_test() {
  let value = Array([Integer(1), String("two"), Boolean(True)])
  let assert Ok(encoded) = pack(value)
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> expect.to_equal(value)
}

pub fn roundtrip_map_test() {
  let value =
    Map([
      #(String("name"), String("Alice")),
      #(String("age"), Integer(30)),
    ])
  let assert Ok(encoded) = pack(value)
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> expect.to_equal(value)
}

pub fn roundtrip_complex_test() {
  let value =
    Map([
      #(
        String("users"),
        Array([
          Map([
            #(String("name"), String("Alice")),
            #(String("active"), Boolean(True)),
          ]),
          Map([
            #(String("name"), String("Bob")),
            #(String("active"), Boolean(False)),
          ]),
        ]),
      ),
      #(String("count"), Integer(2)),
    ])

  let assert Ok(encoded) = pack(value)
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> expect.to_equal(value)
}

// ============================================================================
// Test Suite Decoding Tests (using official msgpack-test-suite)
// ============================================================================

const test_suite_path = "test/test_data/msgpack-test-suite.json"

fn assert_suite_section(
  section: String,
  convert: fn(test_helpers.TestValue) -> value.Value,
) {
  let assert Ok(suite) = load_test_suite(test_suite_path)
  let cases = get_test_cases(suite, section)
  list.each(cases, fn(test_case) {
    let expected = convert(test_case.value)
    list.each(test_case.msgpack, fn(encoding) {
      let assert Ok(decoded) = unpack_exact(encoding)
      decoded |> expect.to_equal(expected)
    })
  })
}

fn assert_suite_section_numeric(section: String) {
  let assert Ok(suite) = load_test_suite(test_suite_path)
  let cases = get_test_cases(suite, section)
  list.each(cases, fn(test_case) {
    let assert IntValue(expected_int) = test_case.value
    list.each(test_case.msgpack, fn(encoding) {
      let assert Ok(decoded) = unpack_exact(encoding)
      assert_numeric_equal(decoded, expected_int)
    })
  })
}

pub fn decode_all_nil_encodings_test() {
  assert_suite_section("10.nil.yaml", fn(_) { Nil })
}

pub fn decode_all_bool_encodings_test() {
  assert_suite_section("11.bool.yaml", fn(tv) {
    let assert BoolValue(b) = tv
    Boolean(b)
  })
}

pub fn decode_all_binary_encodings_test() {
  assert_suite_section("12.binary.yaml", fn(tv) {
    let assert BinaryValue(b) = tv
    Binary(b)
  })
}

pub fn decode_all_negative_number_encodings_test() {
  assert_suite_section_numeric("21.number-negative.yaml")
}

pub fn decode_all_float_encodings_test() {
  assert_suite_section("22.number-float.yaml", fn(tv) {
    let assert FloatValue(f) = tv
    Float(f)
  })
}

pub fn decode_all_bignum_encodings_test() {
  assert_suite_section_numeric("23.number-bignum.yaml")
}

pub fn decode_all_string_utf8_encodings_test() {
  assert_suite_section("31.string-utf8.yaml", fn(tv) {
    let assert StringValue(s) = tv
    String(s)
  })
}

pub fn decode_all_string_emoji_encodings_test() {
  assert_suite_section("32.string-emoji.yaml", fn(tv) {
    let assert StringValue(s) = tv
    String(s)
  })
}

pub fn decode_all_array_encodings_test() {
  assert_suite_section("40.array.yaml", test_value_to_value)
}

pub fn decode_all_map_encodings_test() {
  assert_suite_section("41.map.yaml", test_value_to_value)
}

pub fn decode_all_nested_encodings_test() {
  assert_suite_section("42.nested.yaml", test_value_to_value)
}

pub fn decode_all_timestamp_encodings_test() {
  let assert Ok(suite) = load_test_suite(test_suite_path)
  let cases = get_test_cases(suite, "50.timestamp.yaml")
  list.each(cases, fn(test_case) {
    let assert TimestampValue(expected_seconds, expected_nanos) =
      test_case.value
    list.each(test_case.msgpack, fn(encoding) {
      let assert Ok(decoded_value) = unpack_exact(encoding)
      let assert Ok(ts) = timestamp.decode(decoded_value)
      ts.seconds |> expect.to_equal(expected_seconds)
      ts.nanoseconds |> expect.to_equal(expected_nanos)
    })
  })
}

pub fn decode_all_ext_encodings_test() {
  assert_suite_section("60.ext.yaml", test_value_to_value)
}

pub fn decode_all_positive_number_encodings_test() {
  assert_suite_section_numeric("20.number-positive.yaml")
}

pub fn decode_all_string_ascii_encodings_test() {
  assert_suite_section("30.string-ascii.yaml", fn(tv) {
    let assert StringValue(s) = tv
    String(s)
  })
}

// Helper to convert TestValue to msgpack Value
fn test_value_to_value(tv: test_helpers.TestValue) -> value.Value {
  case tv {
    NilValue -> Nil
    BoolValue(b) -> Boolean(b)
    IntValue(n) -> Integer(n)
    FloatValue(f) -> Float(f)
    StringValue(s) -> String(s)
    BinaryValue(b) -> Binary(b)
    ArrayValue(items) -> Array(list.map(items, test_value_to_value))
    MapValue(pairs) ->
      Map(
        list.map(pairs, fn(pair) {
          #(test_value_to_value(pair.0), test_value_to_value(pair.1))
        }),
      )
    ExtValue(t, d) -> Extension(t, d)
    TimestampValue(s, ns) -> timestamp.encode(Timestamp(s, ns))
  }
}

// The test suite includes multiple valid encodings per value.
// Integer values can be encoded as floats (e.g., 0 as float64),
// so we accept both Integer(n) and Float(n.0) as correct.
fn assert_numeric_equal(decoded: value.Value, expected_int: Int) -> Nil {
  case decoded {
    Integer(n) -> n |> expect.to_equal(expected_int)
    Float(f) -> f |> expect.to_equal(int.to_float(expected_int))
    _ -> panic as "Expected Integer or Float value"
  }
}

// ============================================================================
// Timestamp Tests
// ============================================================================

pub fn timestamp_encode_32bit_test() {
  // Unix epoch (0 seconds) should encode as fixext4
  let ts = Timestamp(0, 0)
  let value = timestamp.encode(ts)
  let assert Ok(data) = pack(value)
  // fixext4 (0xd6), type -1 (0xff), 4 bytes of zeros
  data |> expect.to_equal(<<0xd6, 0xff, 0x00, 0x00, 0x00, 0x00>>)
}

pub fn timestamp_encode_64bit_test() {
  // Timestamp with nanoseconds should encode as fixext8
  let ts = Timestamp(1, 500_000_000)
  let value = timestamp.encode(ts)
  let assert Ok(data) = pack(value)
  // fixext8 (0xd7), type -1 (0xff), 8 bytes
  let assert <<0xd7, 0xff, _:bits>> = data
  Nil
}

pub fn timestamp_decode_32bit_test() {
  // Decode a 32-bit timestamp
  let assert Ok(value) = unpack_exact(<<0xd6, 0xff, 0x00, 0x00, 0x00, 0x01>>)
  let assert Ok(ts) = timestamp.decode(value)
  ts |> expect.to_equal(Timestamp(1, 0))
}

pub fn timestamp_roundtrip_test() {
  // Test round-trip encoding/decoding
  let original = Timestamp(1_234_567_890, 123_456_789)
  let value = timestamp.encode(original)
  let assert Ok(data) = pack(value)
  let assert Ok(decoded_value) = unpack_exact(data)
  let assert Ok(decoded_ts) = timestamp.decode(decoded_value)
  decoded_ts |> expect.to_equal(original)
}

pub fn timestamp_from_unix_seconds_test() {
  let ts = timestamp.from_unix_seconds(1_234_567_890)
  ts |> expect.to_equal(Timestamp(1_234_567_890, 0))
}

pub fn timestamp_from_unix_millis_test() {
  let ts = timestamp.from_unix_millis(1_234_567_890_123)
  ts.seconds |> expect.to_equal(1_234_567_890)
  ts.nanoseconds |> expect.to_equal(123_000_000)
}

pub fn timestamp_to_unix_millis_test() {
  let ts = Timestamp(1_234_567_890, 123_456_789)
  let millis = timestamp.to_unix_millis(ts)
  millis |> expect.to_equal(1_234_567_890_123)
}

pub fn timestamp_is_timestamp_test() {
  // Extension with type -1 is a timestamp
  timestamp.is_timestamp(Extension(-1, <<>>)) |> expect.to_be_true

  // Other extensions are not timestamps
  timestamp.is_timestamp(Extension(0, <<>>)) |> expect.to_be_false
  timestamp.is_timestamp(Extension(1, <<>>)) |> expect.to_be_false

  // Other value types are not timestamps
  timestamp.is_timestamp(Nil) |> expect.to_be_false
  timestamp.is_timestamp(Integer(0)) |> expect.to_be_false
}

// ============================================================================
// Multi-value Stream Decode Tests
// ============================================================================

pub fn decode_stream_two_values_test() {
  let assert Ok(d1) = pack(Integer(42))
  let assert Ok(d2) = pack(String("hello"))
  let stream = <<d1:bits, d2:bits>>

  let assert Ok(#(v1, rest)) = unpack(stream)
  v1 |> expect.to_equal(Integer(42))
  let assert Ok(#(v2, remaining)) = unpack(rest)
  v2 |> expect.to_equal(String("hello"))
  remaining |> expect.to_equal(<<>>)
}

pub fn decode_stream_three_values_test() {
  let assert Ok(d1) = pack(Nil)
  let assert Ok(d2) = pack(Boolean(True))
  let assert Ok(d3) = pack(Integer(100))
  let stream = <<d1:bits, d2:bits, d3:bits>>

  let assert Ok(#(v1, rest1)) = unpack(stream)
  v1 |> expect.to_equal(Nil)
  let assert Ok(#(v2, rest2)) = unpack(rest1)
  v2 |> expect.to_equal(Boolean(True))
  let assert Ok(#(v3, rest3)) = unpack(rest2)
  v3 |> expect.to_equal(Integer(100))
  rest3 |> expect.to_equal(<<>>)
}

// ============================================================================
// Decode Error Path Tests
// ============================================================================

pub fn decode_invalid_utf8_test() {
  // fixstr of 2 bytes with invalid UTF-8
  unpack(<<0xa2, 0xff, 0xfe>>)
  |> expect.to_equal(Error(error.InvalidUtf8))
}

pub fn decode_reserved_format_test() {
  unpack(<<0xc1>>)
  |> expect.to_equal(Error(error.ReservedFormat(0xc1)))
}

pub fn decode_trailing_bytes_test() {
  unpack_exact(<<0xc0, 0xc0>>)
  |> expect.to_equal(Error(error.TrailingBytes(1)))
}

// ============================================================================
// Encode Error Path Tests
// ============================================================================

pub fn encode_integer_too_large_positive_test() {
  let too_big = 18_446_744_073_709_551_616
  pack(value.Integer(too_big))
  |> expect.to_equal(Error(error.IntegerTooLarge(too_big)))
}

pub fn encode_integer_too_negative_test() {
  let too_small = -9_223_372_036_854_775_809
  pack(value.Integer(too_small))
  |> expect.to_equal(Error(error.IntegerTooLarge(too_small)))
}

pub fn encode_invalid_extension_type_code_positive_test() {
  pack(value.Extension(128, <<0x01>>))
  |> expect.to_equal(Error(error.InvalidExtensionTypeCode(128)))
}

pub fn encode_invalid_extension_type_code_negative_test() {
  pack(value.Extension(-129, <<0x01>>))
  |> expect.to_equal(Error(error.InvalidExtensionTypeCode(-129)))
}

// ============================================================================
// Timestamp Edge Case Tests
// ============================================================================

pub fn timestamp_max_nanoseconds_test() {
  let ts = timestamp.Timestamp(1, 999_999_999)
  let v = timestamp.encode(ts)
  let assert Ok(data) = pack(v)
  let assert Ok(decoded_v) = unpack_exact(data)
  let assert Ok(decoded) = timestamp.decode(decoded_v)
  decoded |> expect.to_equal(ts)
}

pub fn timestamp_year_2514_boundary_64bit_test() {
  let ts = timestamp.Timestamp(17_179_869_183, 0)
  let v = timestamp.encode(ts)
  let assert Ok(data) = pack(v)
  let assert <<0xd7, _:bits>> = data
  let assert Ok(decoded_v) = unpack_exact(data)
  let assert Ok(decoded) = timestamp.decode(decoded_v)
  decoded |> expect.to_equal(ts)
}

pub fn timestamp_year_2514_boundary_96bit_test() {
  let ts = timestamp.Timestamp(17_179_869_184, 0)
  let v = timestamp.encode(ts)
  let assert Ok(data) = pack(v)
  let assert <<0xc7, 12, _:bits>> = data
  let assert Ok(decoded_v) = unpack_exact(data)
  let assert Ok(decoded) = timestamp.decode(decoded_v)
  decoded |> expect.to_equal(ts)
}

pub fn timestamp_decode_wrong_extension_type_test() {
  timestamp.decode(value.Extension(5, <<0, 0, 0, 0>>))
  |> expect.to_equal(Error(timestamp.WrongExtensionType(-1, 5)))
}

pub fn timestamp_decode_non_extension_test() {
  timestamp.decode(value.Integer(42))
  |> expect.to_equal(Error(timestamp.NotAnExtension("Integer")))
}

pub fn timestamp_decode_invalid_data_length_test() {
  timestamp.decode(value.Extension(-1, <<0, 0, 0, 0, 0, 0>>))
  |> expect.to_equal(Error(timestamp.InvalidTimestampData(6)))
}

pub fn format_timestamp_error_not_extension_test() {
  timestamp.format_timestamp_error(timestamp.NotAnExtension("Integer"))
  |> expect.to_equal("Expected Extension value, got Integer")
}

pub fn format_timestamp_error_wrong_type_test() {
  timestamp.format_timestamp_error(timestamp.WrongExtensionType(-1, 5))
  |> expect.to_equal("Expected extension type -1, got 5")
}

pub fn format_timestamp_error_invalid_data_test() {
  timestamp.format_timestamp_error(timestamp.InvalidTimestampData(6))
  |> expect.to_equal(
    "Invalid timestamp data length: 6 bytes (expected 4, 8, or 12)",
  )
}

pub fn millis_roundtrip_positive_test() {
  let ts = timestamp.from_unix_millis(1500)
  timestamp.to_unix_millis(ts) |> expect.to_equal(1500)
}

pub fn millis_roundtrip_zero_test() {
  let ts = timestamp.from_unix_millis(0)
  timestamp.to_unix_millis(ts) |> expect.to_equal(0)
  ts |> expect.to_equal(timestamp.Timestamp(0, 0))
}

pub fn is_timestamp_true_test() {
  let v = timestamp.encode(timestamp.Timestamp(0, 0))
  timestamp.is_timestamp(v) |> expect.to_equal(True)
}

pub fn is_timestamp_false_test() {
  timestamp.is_timestamp(value.Integer(42)) |> expect.to_equal(False)
}

pub fn is_timestamp_wrong_ext_test() {
  timestamp.is_timestamp(value.Extension(5, <<>>)) |> expect.to_equal(False)
}

pub fn format_encode_error_integer_too_large_test() {
  error.format_encode_error(error.IntegerTooLarge(999))
  |> expect.to_equal("Integer too large for MessagePack: 999")
}

pub fn format_encode_error_string_too_long_test() {
  error.format_encode_error(error.StringTooLong(5_000_000_000))
  |> expect.to_equal("String too long: 5000000000 bytes (max 4294967295)")
}

pub fn format_encode_error_invalid_ext_type_test() {
  error.format_encode_error(error.InvalidExtensionTypeCode(200))
  |> expect.to_equal("Invalid extension type code: 200 (must be -128 to 127)")
}

pub fn format_decode_error_unexpected_eof_test() {
  error.format_decode_error(error.UnexpectedEof)
  |> expect.to_equal("Unexpected end of input")
}

pub fn format_decode_error_invalid_format_test() {
  error.format_decode_error(error.InvalidFormat(0xc1))
  |> expect.to_equal("Invalid format byte: 193")
}

pub fn format_decode_error_invalid_utf8_test() {
  error.format_decode_error(error.InvalidUtf8)
  |> expect.to_equal("Invalid UTF-8 in string")
}

pub fn format_decode_error_trailing_bytes_test() {
  error.format_decode_error(error.TrailingBytes(5))
  |> expect.to_equal("Unexpected trailing bytes: 5 bytes remaining")
}

pub fn format_decode_error_unsupported_float_test() {
  error.format_decode_error(error.UnsupportedFloat)
  |> expect.to_equal("Unsupported float value (NaN or Infinity)")
}
