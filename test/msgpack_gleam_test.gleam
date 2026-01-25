import gleam/dict
import gleam/list
import gleeunit
import gleeunit/should
import msgpack_gleam.{pack, unpack, unpack_exact}
import msgpack_gleam/timestamp.{Timestamp}
import msgpack_gleam/value.{
  Array, Binary, Boolean, Extension, Float, Integer, Map, Nil, String,
}
import test_helpers.{
  BoolValue, IntValue, NilValue, StringValue, TestCase, bits_to_hex,
  get_test_cases, hex_to_bits, load_test_suite,
}

pub fn main() -> Nil {
  gleeunit.main()
}

// ============================================================================
// Test Suite Loading Tests
// ============================================================================

pub fn load_test_suite_test() {
  let result = load_test_suite("test/test_data/msgpack-test-suite.json")
  should.be_ok(result)

  let assert Ok(suite) = result
  // Verify all expected sections are present
  dict.size(suite) |> should.equal(15)

  // Verify some specific sections
  get_test_cases(suite, "10.nil.yaml") |> list.length |> should.equal(1)
  get_test_cases(suite, "11.bool.yaml") |> list.length |> should.equal(2)
}

pub fn hex_to_bits_test() {
  // Simple single byte
  hex_to_bits("c0") |> should.equal(Ok(<<0xc0>>))

  // Multiple bytes with dashes
  hex_to_bits("c4-01-01") |> should.equal(Ok(<<0xc4, 0x01, 0x01>>))

  // Multiple bytes without dashes
  hex_to_bits("c40101") |> should.equal(Ok(<<0xc4, 0x01, 0x01>>))
}

pub fn bits_to_hex_test() {
  bits_to_hex(<<0xc0>>) |> should.equal("c0")
  bits_to_hex(<<0xc4, 0x01, 0x01>>) |> should.equal("c40101")
}

// ============================================================================
// Test Suite Integration Tests
// ============================================================================

pub fn test_suite_nil_section_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "10.nil.yaml")

  // Should have 1 test case for nil
  list.length(cases) |> should.equal(1)

  // First case should be NilValue with encoding c0
  let assert [TestCase(value: NilValue, msgpack: encodings)] = cases
  list.first(encodings) |> should.equal(Ok(<<0xc0>>))
}

pub fn test_suite_bool_section_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "11.bool.yaml")

  // Should have 2 test cases (false and true)
  list.length(cases) |> should.equal(2)

  // Verify false case
  let assert [TestCase(value: BoolValue(False), msgpack: false_encodings), ..] =
    cases
  list.first(false_encodings) |> should.equal(Ok(<<0xc2>>))
}

pub fn test_suite_positive_int_section_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "20.number-positive.yaml")

  // Should have multiple test cases
  { cases != [] } |> should.be_true

  // First case should be 0
  let assert [TestCase(value: IntValue(0), msgpack: _), ..] = cases
}

pub fn test_suite_string_section_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "30.string-ascii.yaml")

  // Should have test cases
  { cases != [] } |> should.be_true

  // First case should be empty string
  let assert [TestCase(value: StringValue(""), msgpack: _), ..] = cases
}

// ============================================================================
// Nil Encoding/Decoding Tests
// ============================================================================

pub fn encode_nil_test() {
  pack(Nil) |> should.equal(Ok(<<0xc0>>))
}

pub fn decode_nil_test() {
  unpack(<<0xc0>>) |> should.equal(Ok(#(Nil, <<>>)))
  unpack_exact(<<0xc0>>) |> should.equal(Ok(Nil))
}

// ============================================================================
// Boolean Encoding/Decoding Tests
// ============================================================================

pub fn encode_bool_test() {
  pack(Boolean(False)) |> should.equal(Ok(<<0xc2>>))
  pack(Boolean(True)) |> should.equal(Ok(<<0xc3>>))
}

pub fn decode_bool_test() {
  unpack(<<0xc2>>) |> should.equal(Ok(#(Boolean(False), <<>>)))
  unpack(<<0xc3>>) |> should.equal(Ok(#(Boolean(True), <<>>)))
}

// ============================================================================
// Integer Encoding/Decoding Tests
// ============================================================================

pub fn encode_positive_fixint_test() {
  // 0-127 should use fixint (single byte)
  pack(Integer(0)) |> should.equal(Ok(<<0x00>>))
  pack(Integer(1)) |> should.equal(Ok(<<0x01>>))
  pack(Integer(127)) |> should.equal(Ok(<<0x7f>>))
}

pub fn decode_positive_fixint_test() {
  unpack(<<0x00>>) |> should.equal(Ok(#(Integer(0), <<>>)))
  unpack(<<0x01>>) |> should.equal(Ok(#(Integer(1), <<>>)))
  unpack(<<0x7f>>) |> should.equal(Ok(#(Integer(127), <<>>)))
}

pub fn encode_negative_fixint_test() {
  // -32 to -1 should use negative fixint
  pack(Integer(-1)) |> should.equal(Ok(<<0xff>>))
  pack(Integer(-32)) |> should.equal(Ok(<<0xe0>>))
}

pub fn decode_negative_fixint_test() {
  unpack(<<0xff>>) |> should.equal(Ok(#(Integer(-1), <<>>)))
  unpack(<<0xe0>>) |> should.equal(Ok(#(Integer(-32), <<>>)))
}

pub fn encode_uint8_test() {
  // 128-255 should use uint8
  pack(Integer(128)) |> should.equal(Ok(<<0xcc, 128>>))
  pack(Integer(255)) |> should.equal(Ok(<<0xcc, 255>>))
}

pub fn decode_uint8_test() {
  unpack(<<0xcc, 128>>) |> should.equal(Ok(#(Integer(128), <<>>)))
  unpack(<<0xcc, 255>>) |> should.equal(Ok(#(Integer(255), <<>>)))
}

pub fn encode_int8_test() {
  // -128 to -33 should use int8
  pack(Integer(-33)) |> should.equal(Ok(<<0xd0, 0xdf>>))
  pack(Integer(-128)) |> should.equal(Ok(<<0xd0, 0x80>>))
}

pub fn decode_int8_test() {
  unpack(<<0xd0, 0xdf>>) |> should.equal(Ok(#(Integer(-33), <<>>)))
  unpack(<<0xd0, 0x80>>) |> should.equal(Ok(#(Integer(-128), <<>>)))
}

pub fn encode_uint16_test() {
  pack(Integer(256)) |> should.equal(Ok(<<0xcd, 0x01, 0x00>>))
  pack(Integer(65_535)) |> should.equal(Ok(<<0xcd, 0xff, 0xff>>))
}

pub fn decode_uint16_test() {
  unpack(<<0xcd, 0x01, 0x00>>) |> should.equal(Ok(#(Integer(256), <<>>)))
  unpack(<<0xcd, 0xff, 0xff>>) |> should.equal(Ok(#(Integer(65_535), <<>>)))
}

pub fn encode_int16_test() {
  pack(Integer(-129)) |> should.equal(Ok(<<0xd1, 0xff, 0x7f>>))
  pack(Integer(-32_768)) |> should.equal(Ok(<<0xd1, 0x80, 0x00>>))
}

pub fn decode_int16_test() {
  unpack(<<0xd1, 0xff, 0x7f>>) |> should.equal(Ok(#(Integer(-129), <<>>)))
  unpack(<<0xd1, 0x80, 0x00>>) |> should.equal(Ok(#(Integer(-32_768), <<>>)))
}

pub fn encode_uint32_test() {
  pack(Integer(65_536)) |> should.equal(Ok(<<0xce, 0x00, 0x01, 0x00, 0x00>>))
  pack(Integer(4_294_967_295))
  |> should.equal(Ok(<<0xce, 0xff, 0xff, 0xff, 0xff>>))
}

pub fn decode_uint32_test() {
  unpack(<<0xce, 0x00, 0x01, 0x00, 0x00>>)
  |> should.equal(Ok(#(Integer(65_536), <<>>)))
  unpack(<<0xce, 0xff, 0xff, 0xff, 0xff>>)
  |> should.equal(Ok(#(Integer(4_294_967_295), <<>>)))
}

pub fn encode_uint64_test() {
  pack(Integer(4_294_967_296))
  |> should.equal(Ok(<<0xcf, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00>>))
}

pub fn decode_uint64_test() {
  unpack(<<0xcf, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00>>)
  |> should.equal(Ok(#(Integer(4_294_967_296), <<>>)))
}

// ============================================================================
// Float Encoding/Decoding Tests
// ============================================================================

pub fn encode_float_test() {
  // Always encodes as float64
  let assert Ok(result) = pack(Float(1.0))
  // Check first byte is float64 marker
  let assert <<0xcb, _:bits>> = result
}

pub fn decode_float32_test() {
  // 1.0 as float32: 0x3f800000
  unpack(<<0xca, 0x3f, 0x80, 0x00, 0x00>>)
  |> should.equal(Ok(#(Float(1.0), <<>>)))
}

pub fn decode_float64_test() {
  // 1.0 as float64
  unpack(<<0xcb, 0x3f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
  |> should.equal(Ok(#(Float(1.0), <<>>)))
}

// ============================================================================
// String Encoding/Decoding Tests
// ============================================================================

pub fn encode_fixstr_test() {
  // Empty string
  pack(String("")) |> should.equal(Ok(<<0xa0>>))
  // "a" (1 char)
  pack(String("a")) |> should.equal(Ok(<<0xa1, 0x61>>))
  // 31 chars (max fixstr)
  let s31 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let assert Ok(result) = pack(String(s31))
  let assert <<0xbf, _:bits>> = result
}

pub fn decode_fixstr_test() {
  unpack(<<0xa0>>) |> should.equal(Ok(#(String(""), <<>>)))
  unpack(<<0xa1, 0x61>>) |> should.equal(Ok(#(String("a"), <<>>)))
}

pub fn encode_str8_test() {
  // 32 chars (min str8)
  let s32 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let assert Ok(result) = pack(String(s32))
  let assert <<0xd9, 32, _:bits>> = result
}

pub fn decode_str8_test() {
  unpack(<<0xd9, 0x01, 0x61>>) |> should.equal(Ok(#(String("a"), <<>>)))
}

// ============================================================================
// Binary Encoding/Decoding Tests
// ============================================================================

pub fn encode_bin8_test() {
  pack(Binary(<<>>)) |> should.equal(Ok(<<0xc4, 0x00>>))
  pack(Binary(<<0x01>>)) |> should.equal(Ok(<<0xc4, 0x01, 0x01>>))
}

pub fn decode_bin8_test() {
  unpack(<<0xc4, 0x00>>) |> should.equal(Ok(#(Binary(<<>>), <<>>)))
  unpack(<<0xc4, 0x01, 0x01>>) |> should.equal(Ok(#(Binary(<<0x01>>), <<>>)))
}

// ============================================================================
// Array Encoding/Decoding Tests
// ============================================================================

pub fn encode_fixarray_test() {
  // Empty array
  pack(Array([])) |> should.equal(Ok(<<0x90>>))
  // Array with one element
  pack(Array([Integer(1)])) |> should.equal(Ok(<<0x91, 0x01>>))
}

pub fn decode_fixarray_test() {
  unpack(<<0x90>>) |> should.equal(Ok(#(Array([]), <<>>)))
  unpack(<<0x91, 0x01>>) |> should.equal(Ok(#(Array([Integer(1)]), <<>>)))
}

pub fn encode_nested_array_test() {
  pack(Array([Array([])]))
  |> should.equal(Ok(<<0x91, 0x90>>))
}

pub fn decode_nested_array_test() {
  unpack(<<0x91, 0x90>>) |> should.equal(Ok(#(Array([Array([])]), <<>>)))
}

// ============================================================================
// Map Encoding/Decoding Tests
// ============================================================================

pub fn encode_fixmap_test() {
  // Empty map
  pack(Map([])) |> should.equal(Ok(<<0x80>>))
  // Map with one entry
  pack(Map([#(String("a"), Integer(1))]))
  |> should.equal(Ok(<<0x81, 0xa1, 0x61, 0x01>>))
}

pub fn decode_fixmap_test() {
  unpack(<<0x80>>) |> should.equal(Ok(#(Map([]), <<>>)))
  unpack(<<0x81, 0xa1, 0x61, 0x01>>)
  |> should.equal(Ok(#(Map([#(String("a"), Integer(1))]), <<>>)))
}

// ============================================================================
// Extension Type Encoding/Decoding Tests
// ============================================================================

pub fn encode_fixext1_test() {
  pack(Extension(1, <<0xaa>>))
  |> should.equal(Ok(<<0xd4, 0x01, 0xaa>>))
}

pub fn decode_fixext1_test() {
  unpack(<<0xd4, 0x01, 0xaa>>)
  |> should.equal(Ok(#(Extension(1, <<0xaa>>), <<>>)))
}

pub fn encode_negative_ext_type_test() {
  // Timestamp extension is type -1
  pack(Extension(-1, <<0x00, 0x00, 0x00, 0x00>>))
  |> should.equal(Ok(<<0xd6, 0xff, 0x00, 0x00, 0x00, 0x00>>))
}

pub fn decode_negative_ext_type_test() {
  unpack(<<0xd6, 0xff, 0x00, 0x00, 0x00, 0x00>>)
  |> should.equal(Ok(#(Extension(-1, <<0x00, 0x00, 0x00, 0x00>>), <<>>)))
}

// ============================================================================
// Round-trip Tests
// ============================================================================

pub fn roundtrip_nil_test() {
  let value = Nil
  let assert Ok(encoded) = pack(value)
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> should.equal(value)
}

pub fn roundtrip_bool_test() {
  let assert Ok(encoded_true) = pack(Boolean(True))
  let assert Ok(decoded_true) = unpack_exact(encoded_true)
  decoded_true |> should.equal(Boolean(True))

  let assert Ok(encoded_false) = pack(Boolean(False))
  let assert Ok(decoded_false) = unpack_exact(encoded_false)
  decoded_false |> should.equal(Boolean(False))
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
    decoded |> should.equal(value)
  })
}

pub fn roundtrip_string_test() {
  let test_values = ["", "a", "hello", "hello world", "こんにちは"]

  list.each(test_values, fn(s) {
    let value = String(s)
    let assert Ok(encoded) = pack(value)
    let assert Ok(decoded) = unpack_exact(encoded)
    decoded |> should.equal(value)
  })
}

pub fn roundtrip_array_test() {
  let value = Array([Integer(1), String("two"), Boolean(True)])
  let assert Ok(encoded) = pack(value)
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> should.equal(value)
}

pub fn roundtrip_map_test() {
  let value =
    Map([
      #(String("name"), String("Alice")),
      #(String("age"), Integer(30)),
    ])
  let assert Ok(encoded) = pack(value)
  let assert Ok(decoded) = unpack_exact(encoded)
  decoded |> should.equal(value)
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
  decoded |> should.equal(value)
}

// ============================================================================
// Test Suite Decoding Tests (using official msgpack-test-suite)
// ============================================================================

pub fn decode_all_nil_encodings_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "10.nil.yaml")

  list.each(cases, fn(test_case) {
    list.each(test_case.msgpack, fn(encoding) {
      let assert Ok(decoded) = unpack_exact(encoding)
      decoded |> should.equal(Nil)
    })
  })
}

pub fn decode_all_bool_encodings_test() {
  let assert Ok(suite) =
    load_test_suite("test/test_data/msgpack-test-suite.json")
  let cases = get_test_cases(suite, "11.bool.yaml")

  list.each(cases, fn(test_case) {
    let expected = case test_case.value {
      test_helpers.BoolValue(b) -> Boolean(b)
      _ -> panic as "Expected bool value"
    }

    list.each(test_case.msgpack, fn(encoding) {
      let assert Ok(decoded) = unpack_exact(encoding)
      decoded |> should.equal(expected)
    })
  })
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
  data |> should.equal(<<0xd6, 0xff, 0x00, 0x00, 0x00, 0x00>>)
}

pub fn timestamp_encode_64bit_test() {
  // Timestamp with nanoseconds should encode as fixext8
  let ts = Timestamp(1, 500_000_000)
  let value = timestamp.encode(ts)
  let assert Ok(data) = pack(value)
  // fixext8 (0xd7), type -1 (0xff), 8 bytes
  let assert <<0xd7, 0xff, _:bits>> = data
}

pub fn timestamp_decode_32bit_test() {
  // Decode a 32-bit timestamp
  let assert Ok(value) = unpack_exact(<<0xd6, 0xff, 0x00, 0x00, 0x00, 0x01>>)
  let assert Ok(ts) = timestamp.decode(value)
  ts |> should.equal(Timestamp(1, 0))
}

pub fn timestamp_roundtrip_test() {
  // Test round-trip encoding/decoding
  let original = Timestamp(1_234_567_890, 123_456_789)
  let value = timestamp.encode(original)
  let assert Ok(data) = pack(value)
  let assert Ok(decoded_value) = unpack_exact(data)
  let assert Ok(decoded_ts) = timestamp.decode(decoded_value)
  decoded_ts |> should.equal(original)
}

pub fn timestamp_from_unix_seconds_test() {
  let ts = timestamp.from_unix_seconds(1_234_567_890)
  ts |> should.equal(Timestamp(1_234_567_890, 0))
}

pub fn timestamp_from_unix_millis_test() {
  let ts = timestamp.from_unix_millis(1_234_567_890_123)
  ts.seconds |> should.equal(1_234_567_890)
  ts.nanoseconds |> should.equal(123_000_000)
}

pub fn timestamp_to_unix_millis_test() {
  let ts = Timestamp(1_234_567_890, 123_456_789)
  let millis = timestamp.to_unix_millis(ts)
  millis |> should.equal(1_234_567_890_123)
}

pub fn timestamp_is_timestamp_test() {
  // Extension with type -1 is a timestamp
  timestamp.is_timestamp(Extension(-1, <<>>)) |> should.be_true

  // Other extensions are not timestamps
  timestamp.is_timestamp(Extension(0, <<>>)) |> should.be_false
  timestamp.is_timestamp(Extension(1, <<>>)) |> should.be_false

  // Other value types are not timestamps
  timestamp.is_timestamp(Nil) |> should.be_false
  timestamp.is_timestamp(Integer(0)) |> should.be_false
}
