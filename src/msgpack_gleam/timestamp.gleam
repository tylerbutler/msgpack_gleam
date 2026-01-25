/// MessagePack Timestamp Extension Type (-1)
///
/// The timestamp extension type represents an instantaneous point on the
/// time-line. It supports nanosecond precision from 1970-01-01 00:00:00 UTC.
import gleam/bit_array
import msgpack_gleam/value.{type Value, Extension}

/// The MessagePack extension type code for timestamps
pub const timestamp_type_code: Int = -1

/// A timestamp value with seconds since Unix epoch and nanoseconds
pub type Timestamp {
  Timestamp(seconds: Int, nanoseconds: Int)
}

/// Create a MessagePack Value from a timestamp.
/// Chooses the smallest encoding format based on the values.
pub fn encode(timestamp: Timestamp) -> Value {
  let Timestamp(seconds, nanoseconds) = timestamp

  case nanoseconds, seconds {
    // Timestamp 32: 4 bytes, stores seconds in 32-bit unsigned int
    // Range: [1970-01-01 00:00:00 UTC, 2106-02-07 06:28:16 UTC)
    0, s if s >= 0 && s <= 4_294_967_295 ->
      Extension(timestamp_type_code, <<s:32>>)

    // Timestamp 64: 8 bytes, stores nanoseconds in 30-bit and seconds in 34-bit
    // Range: [1970-01-01 00:00:00.000000000 UTC, 2514-05-30 01:53:04.000000000 UTC)
    ns, s if s >= 0 && s <= 17_179_869_183 && ns >= 0 && ns <= 999_999_999 -> {
      // nanoseconds (30 bits) | seconds (34 bits)
      let combined = { ns * 4 } + { s / 4_294_967_296 }
      let seconds_lower = s % 4_294_967_296
      Extension(timestamp_type_code, <<combined:32, seconds_lower:32>>)
    }

    // Timestamp 96: 12 bytes, stores nanoseconds in 32-bit and seconds in 64-bit signed
    // Range: unlimited
    ns, s -> {
      // Convert negative seconds to unsigned (two's complement)
      let unsigned_s = case s < 0 {
        True -> s + 18_446_744_073_709_551_616
        False -> s
      }
      Extension(timestamp_type_code, <<ns:32, unsigned_s:64>>)
    }
  }
}

/// Decode a MessagePack Extension value as a timestamp.
/// Returns an error if the extension is not a timestamp type (-1).
pub fn decode(value: Value) -> Result(Timestamp, String) {
  case value {
    Extension(type_code, data) if type_code == timestamp_type_code -> {
      let size = bit_array.byte_size(data)
      case size, data {
        // Timestamp 32: 4 bytes
        4, <<seconds:32>> -> Ok(Timestamp(seconds, 0))

        // Timestamp 64: 8 bytes
        8, <<combined:32, seconds_lower:32>> -> {
          // Extract nanoseconds (upper 30 bits) and seconds (34 bits total)
          let nanoseconds = combined / 4
          let seconds_upper = combined % 4
          let seconds = seconds_upper * 4_294_967_296 + seconds_lower
          Ok(Timestamp(seconds, nanoseconds))
        }

        // Timestamp 96: 12 bytes
        12, <<nanoseconds:32, seconds:64-signed>> ->
          Ok(Timestamp(seconds, nanoseconds))

        _, _ -> Error("Invalid timestamp data length: " <> int_to_string(size))
      }
    }
    Extension(type_code, _) ->
      Error(
        "Expected timestamp extension type (-1), got: "
        <> int_to_string(type_code),
      )
    _ -> Error("Expected Extension value, got different type")
  }
}

/// Check if a Value is a timestamp extension
pub fn is_timestamp(value: Value) -> Bool {
  case value {
    Extension(tc, _) if tc == timestamp_type_code -> True
    _ -> False
  }
}

/// Create a timestamp from Unix seconds (no nanoseconds)
pub fn from_unix_seconds(seconds: Int) -> Timestamp {
  Timestamp(seconds, 0)
}

/// Create a timestamp from Unix milliseconds
pub fn from_unix_millis(millis: Int) -> Timestamp {
  let seconds = millis / 1000
  let nanoseconds = { millis % 1000 } * 1_000_000
  Timestamp(seconds, nanoseconds)
}

/// Convert a timestamp to Unix seconds (truncating nanoseconds)
pub fn to_unix_seconds(timestamp: Timestamp) -> Int {
  timestamp.seconds
}

/// Convert a timestamp to Unix milliseconds
pub fn to_unix_millis(timestamp: Timestamp) -> Int {
  timestamp.seconds * 1000 + timestamp.nanoseconds / 1_000_000
}

// Helper to convert int to string (avoiding dependency on gleam/int)
fn int_to_string(n: Int) -> String {
  case n {
    0 -> "0"
    _ if n < 0 -> "-" <> int_to_string_positive(-n)
    _ -> int_to_string_positive(n)
  }
}

fn int_to_string_positive(n: Int) -> String {
  case n {
    0 -> ""
    _ -> {
      let digit = case n % 10 {
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
        _ -> "?"
      }
      int_to_string_positive(n / 10) <> digit
    }
  }
}
