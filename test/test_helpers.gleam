import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile

/// A test case from the msgpack-test-suite
pub type TestCase {
  TestCase(
    /// The expected value (could be nil, bool, number, string, binary, array, map, etc.)
    value: TestValue,
    /// Valid MessagePack binary encodings (any of these are correct)
    msgpack: List(BitArray),
  )
}

/// Represents a test value from the test suite
pub type TestValue {
  NilValue
  BoolValue(Bool)
  IntValue(Int)
  FloatValue(Float)
  StringValue(String)
  BinaryValue(BitArray)
  ArrayValue(List(TestValue))
  MapValue(List(#(TestValue, TestValue)))
  ExtValue(type_code: Int, data: BitArray)
  TimestampValue(seconds: Int, nanoseconds: Int)
}

/// Load the test suite from the JSON file
pub fn load_test_suite(
  path: String,
) -> Result(Dict(String, List(TestCase)), String) {
  use content <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(_) { "Failed to read file: " <> path }),
  )

  // Parse JSON into a dict of string -> dynamic
  let decoder = decode.dict(decode.string, decode.dynamic)

  use sections <- result.try(
    json.parse(content, decoder)
    |> result.map_error(fn(_) { "Failed to parse JSON" }),
  )

  // Parse each section
  dict.to_list(sections)
  |> list.try_map(fn(pair) {
    let #(name, tests) = pair
    case parse_test_section(name, tests) {
      Ok(test_cases) -> Ok(#(name, test_cases))
      Error(e) -> Error(e)
    }
  })
  |> result.map(dict.from_list)
}

/// Parse a single test section (e.g., "10.nil.yaml")
fn parse_test_section(
  section_name: String,
  data: Dynamic,
) -> Result(List(TestCase), String) {
  let list_decoder = decode.list(decode.dynamic)
  case decode.run(data, list_decoder) {
    Ok(items) ->
      list.try_map(items, fn(item) { parse_test_case(section_name, item) })
    Error(_) -> Error("Test section must be an array")
  }
}

/// Parse a single test case
fn parse_test_case(
  section_name: String,
  data: Dynamic,
) -> Result(TestCase, String) {
  let dict_decoder = decode.dict(decode.string, decode.dynamic)
  case decode.run(data, dict_decoder) {
    Ok(obj) -> {
      // Get msgpack encodings
      let msgpack_result = case dict.get(obj, "msgpack") {
        Ok(mp) -> parse_msgpack_list(mp)
        Error(_) -> Error("Missing msgpack field")
      }

      use msgpack <- result.try(msgpack_result)

      // Parse value based on section type
      let value_result = case get_section_type(section_name) {
        "nil" -> Ok(NilValue)
        "bool" -> parse_bool_value(obj)
        "binary" -> parse_binary_value(obj)
        "number" -> parse_number_value(obj)
        "string" -> parse_string_value(obj)
        "array" -> parse_array_value(obj)
        "map" -> parse_map_value(obj)
        "nested" -> parse_nested_value(obj)
        "timestamp" -> parse_timestamp_value(obj)
        "ext" -> parse_ext_value(obj)
        other -> Error("Unknown section type: " <> other)
      }

      use value <- result.try(value_result)
      Ok(TestCase(value:, msgpack:))
    }
    Error(_) -> Error("Test case must be an object")
  }
}

/// Get the type of a section from its name
fn get_section_type(name: String) -> String {
  case string.split(name, ".") {
    [_, type_part, ..] -> {
      // Handle names like "number-positive" -> "number"
      case string.split(type_part, "-") {
        [base, ..] -> base
        [] -> type_part
      }
    }
    _ -> ""
  }
}

/// Parse the msgpack hex strings to BitArrays
fn parse_msgpack_list(data: Dynamic) -> Result(List(BitArray), String) {
  let list_decoder = decode.list(decode.string)
  case decode.run(data, list_decoder) {
    Ok(hex_strings) -> list.try_map(hex_strings, hex_to_bits)
    Error(_) -> Error("msgpack must be a list of strings")
  }
}

/// Convert a hex string like "c0" or "c4-01-01" to a BitArray
pub fn hex_to_bits(hex: String) -> Result(BitArray, String) {
  hex
  |> string.replace("-", "")
  |> parse_hex_string
}

fn parse_hex_string(hex: String) -> Result(BitArray, String) {
  let chars = string.to_graphemes(hex)
  parse_hex_chars(chars, <<>>)
}

fn parse_hex_chars(
  chars: List(String),
  acc: BitArray,
) -> Result(BitArray, String) {
  case chars {
    [] -> Ok(acc)
    [a, b, ..rest] -> {
      case hex_char_to_int(a), hex_char_to_int(b) {
        Ok(high), Ok(low) -> {
          let byte = high * 16 + low
          parse_hex_chars(rest, <<acc:bits, byte:8>>)
        }
        _, _ -> Error("Invalid hex character")
      }
    }
    [_] -> Error("Odd number of hex characters")
  }
}

fn hex_char_to_int(c: String) -> Result(Int, Nil) {
  case c {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    "a" | "A" -> Ok(10)
    "b" | "B" -> Ok(11)
    "c" | "C" -> Ok(12)
    "d" | "D" -> Ok(13)
    "e" | "E" -> Ok(14)
    "f" | "F" -> Ok(15)
    _ -> Error(Nil)
  }
}

/// Parse a bool value
fn parse_bool_value(obj: Dict(String, Dynamic)) -> Result(TestValue, String) {
  case dict.get(obj, "bool") {
    Ok(v) ->
      case decode.run(v, decode.bool) {
        Ok(b) -> Ok(BoolValue(b))
        Error(_) -> Error("bool field must be a boolean")
      }
    Error(_) -> Error("Missing bool field")
  }
}

/// Parse a binary value (hex string)
fn parse_binary_value(obj: Dict(String, Dynamic)) -> Result(TestValue, String) {
  case dict.get(obj, "binary") {
    Ok(v) ->
      case decode.run(v, decode.string) {
        Ok(hex) ->
          case hex {
            "" -> Ok(BinaryValue(<<>>))
            _ ->
              case hex_to_bits(hex) {
                Ok(bits) -> Ok(BinaryValue(bits))
                Error(e) -> Error(e)
              }
          }
        Error(_) -> Error("binary field must be a string")
      }
    Error(_) -> Error("Missing binary field")
  }
}

/// Parse a number value (int or float)
/// Handles both "number" field and "bignum" field (for large integers as strings)
fn parse_number_value(obj: Dict(String, Dynamic)) -> Result(TestValue, String) {
  case dict.get(obj, "number") {
    Ok(v) -> {
      // Try int first, then float
      case decode.run(v, decode.int) {
        Ok(n) -> Ok(IntValue(n))
        Error(_) ->
          case decode.run(v, decode.float) {
            Ok(f) -> Ok(FloatValue(f))
            Error(_) -> Error("number field must be a number")
          }
      }
    }
    Error(_) -> {
      // Try bignum field (large integers stored as strings)
      case dict.get(obj, "bignum") {
        Ok(v) ->
          case decode.run(v, decode.string) {
            Ok(s) ->
              case int.parse(s) {
                Ok(n) -> Ok(IntValue(n))
                Error(_) -> Error("bignum field must be a valid integer string")
              }
            Error(_) -> Error("bignum field must be a string")
          }
        Error(_) -> Error("Missing number or bignum field")
      }
    }
  }
}

/// Parse a string value
fn parse_string_value(obj: Dict(String, Dynamic)) -> Result(TestValue, String) {
  case dict.get(obj, "string") {
    Ok(v) ->
      case decode.run(v, decode.string) {
        Ok(s) -> Ok(StringValue(s))
        Error(_) -> Error("string field must be a string")
      }
    Error(_) -> Error("Missing string field")
  }
}

/// Parse an array value
fn parse_array_value(obj: Dict(String, Dynamic)) -> Result(TestValue, String) {
  case dict.get(obj, "array") {
    Ok(v) -> {
      case decode.run(v, decode.list(decode.dynamic)) {
        Ok(items) -> {
          list.try_map(items, parse_dynamic_value)
          |> result.map(ArrayValue)
        }
        Error(_) -> Error("array field must be an array")
      }
    }
    Error(_) -> Error("Missing array field")
  }
}

/// Parse a map value
fn parse_map_value(obj: Dict(String, Dynamic)) -> Result(TestValue, String) {
  case dict.get(obj, "map") {
    Ok(v) -> parse_dynamic_map(v)
    Error(_) -> Error("Missing map field")
  }
}

fn parse_dynamic_map(data: Dynamic) -> Result(TestValue, String) {
  // Maps in the test suite are represented as JSON objects (string keys only)
  case decode.run(data, decode.dict(decode.string, decode.dynamic)) {
    Ok(obj) -> {
      dict.to_list(obj)
      |> list.try_map(fn(pair) {
        let #(key, value) = pair
        use v <- result.try(parse_dynamic_value(value))
        Ok(#(StringValue(key), v))
      })
      |> result.map(MapValue)
    }
    Error(_) -> Error("map field must be a JSON object")
  }
}

/// Parse a nested value (complex structure with arrays/maps)
/// In the test suite, nested values use "array" or "map" fields
fn parse_nested_value(obj: Dict(String, Dynamic)) -> Result(TestValue, String) {
  // Try array first
  case dict.get(obj, "array") {
    Ok(v) -> {
      case decode.run(v, decode.list(decode.dynamic)) {
        Ok(items) -> {
          list.try_map(items, parse_dynamic_value)
          |> result.map(ArrayValue)
        }
        Error(_) -> Error("array field must be an array")
      }
    }
    Error(_) -> {
      // Try map
      case dict.get(obj, "map") {
        Ok(v) -> parse_dynamic_map(v)
        Error(_) -> {
          // Try value field as fallback
          case dict.get(obj, "value") {
            Ok(v) -> parse_dynamic_value(v)
            Error(_) -> Error("Missing array, map, or value field in nested")
          }
        }
      }
    }
  }
}

/// Parse a timestamp value
fn parse_timestamp_value(
  obj: Dict(String, Dynamic),
) -> Result(TestValue, String) {
  case dict.get(obj, "timestamp") {
    Ok(v) -> {
      case decode.run(v, decode.list(decode.int)) {
        Ok(values) ->
          case values {
            [seconds, nanoseconds] -> Ok(TimestampValue(seconds:, nanoseconds:))
            [seconds] -> Ok(TimestampValue(seconds:, nanoseconds: 0))
            _ -> Error("timestamp must be [seconds] or [seconds, nanoseconds]")
          }
        Error(_) ->
          Error("timestamp must be [seconds] or [seconds, nanoseconds]")
      }
    }
    Error(_) -> Error("Missing timestamp field")
  }
}

/// Parse an extension value
fn parse_ext_value(obj: Dict(String, Dynamic)) -> Result(TestValue, String) {
  case dict.get(obj, "ext") {
    Ok(v) -> {
      case decode.run(v, decode.list(decode.dynamic)) {
        Ok(items) ->
          case items {
            [type_dyn, data_dyn] -> {
              case
                decode.run(type_dyn, decode.int),
                decode.run(data_dyn, decode.string)
              {
                Ok(type_code), Ok(hex_data) -> {
                  case hex_data {
                    "" -> Ok(ExtValue(type_code:, data: <<>>))
                    _ ->
                      case hex_to_bits(hex_data) {
                        Ok(data) -> Ok(ExtValue(type_code:, data:))
                        Error(e) -> Error(e)
                      }
                  }
                }
                _, _ -> Error("ext must be [type_code: int, data: hex_string]")
              }
            }
            _ -> Error("ext must be [type_code, data]")
          }
        Error(_) -> Error("ext must be [type_code, data]")
      }
    }
    Error(_) -> Error("Missing ext field")
  }
}

/// Parse any dynamic value (for arrays/maps/nested structures)
fn parse_dynamic_value(data: Dynamic) -> Result(TestValue, String) {
  // Try each type in order using decoders
  // We need to try them in order since dynamic.classify may return
  // different values on different targets (Erlang vs JS)

  // Try nil
  case decode.run(data, decode.optional(decode.dynamic)) {
    Ok(option.None) -> Ok(NilValue)
    _ -> parse_non_nil_value(data)
  }
}

fn parse_non_nil_value(data: Dynamic) -> Result(TestValue, String) {
  // Try bool
  case decode.run(data, decode.bool) {
    Ok(b) -> Ok(BoolValue(b))
    Error(_) ->
      // Try int
      case decode.run(data, decode.int) {
        Ok(n) -> Ok(IntValue(n))
        Error(_) ->
          // Try float
          case decode.run(data, decode.float) {
            Ok(f) -> Ok(FloatValue(f))
            Error(_) ->
              // Try string
              case decode.run(data, decode.string) {
                Ok(s) -> Ok(StringValue(s))
                Error(_) ->
                  // Try list (array)
                  case decode.run(data, decode.list(decode.dynamic)) {
                    Ok(items) -> {
                      list.try_map(items, parse_dynamic_value)
                      |> result.map(ArrayValue)
                    }
                    Error(_) ->
                      // Try dict (map/object)
                      case
                        decode.run(
                          data,
                          decode.dict(decode.string, decode.dynamic),
                        )
                      {
                        Ok(obj) -> {
                          dict.to_list(obj)
                          |> list.try_map(fn(pair) {
                            let #(key, value) = pair
                            use v <- result.try(parse_dynamic_value(value))
                            Ok(#(StringValue(key), v))
                          })
                          |> result.map(MapValue)
                        }
                        Error(_) ->
                          Error(
                            "Unsupported dynamic type: "
                            <> dynamic.classify(data),
                          )
                      }
                  }
              }
          }
      }
  }
}

/// Convert bits to hex string for debugging
pub fn bits_to_hex(bits: BitArray) -> String {
  bits_to_hex_acc(bits, "")
}

fn bits_to_hex_acc(bits: BitArray, acc: String) -> String {
  case bits {
    <<byte:8, rest:bits>> -> {
      let hex = int_to_hex_byte(byte)
      bits_to_hex_acc(rest, acc <> hex)
    }
    _ -> acc
  }
}

fn int_to_hex_byte(n: Int) -> String {
  let high = n / 16
  let low = n % 16
  int_to_hex_char(high) <> int_to_hex_char(low)
}

fn int_to_hex_char(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    15 -> "f"
    _ -> "?"
  }
}

/// Get test cases for a specific section
pub fn get_test_cases(
  suite: Dict(String, List(TestCase)),
  section: String,
) -> List(TestCase) {
  dict.get(suite, section)
  |> result.unwrap([])
}

/// Get the first (canonical) encoding from a test case
pub fn canonical_encoding(test_case: TestCase) -> Option(BitArray) {
  case test_case.msgpack {
    [first, ..] -> Some(first)
    [] -> None
  }
}
