/// MessagePack Timestamp Extension Type (-1)
///
/// The timestamp extension type represents an instantaneous point on the
/// time-line. It supports nanosecond precision from 1970-01-01 00:00:00 UTC.
///
/// Uses `gleam/time/timestamp.Timestamp` as the timestamp representation,
/// providing seamless interop with the Gleam time ecosystem.
import gleam/bit_array
import gleam/int
import gleam/time/timestamp.{type Timestamp}
import msgpack_gleam/value.{type Value, Extension}

/// The MessagePack extension type code for timestamps
pub const timestamp_type_code: Int = -1

/// Errors that can occur during timestamp operations.
pub type TimestampError {
  /// Nanoseconds value is outside the valid range [0, 999_999_999]
  InvalidNanoseconds(Int)
  /// Extension value is not a timestamp (wrong type code)
  NotATimestamp(expected: Int, got: Int)
  /// The value is not an Extension at all
  NotAnExtension(String)
  /// The timestamp binary payload has an invalid length
  InvalidDataLength(Int)
}

/// Format a TimestampError as a human-readable string.
pub fn format_timestamp_error(error: TimestampError) -> String {
  case error {
    NotAnExtension(got) -> "Expected Extension value, got " <> got
    NotATimestamp(expected, got) ->
      "Expected extension type "
      <> int.to_string(expected)
      <> ", got "
      <> int.to_string(got)
    InvalidDataLength(size) ->
      "Invalid timestamp data length: "
      <> int.to_string(size)
      <> " bytes (expected 4, 8, or 12)"
    InvalidNanoseconds(ns) ->
      "Invalid nanoseconds: "
      <> int.to_string(ns)
      <> " (must be 0 to 999999999)"
  }
}

/// Create a MessagePack Value from a timestamp.
/// Chooses the smallest encoding format based on the values.
pub fn encode(ts: Timestamp) -> Value {
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(ts)

  // Normalize: ensure nanoseconds is in [0, 999_999_999]
  let #(seconds, nanoseconds) = case nanoseconds < 0 {
    True -> #(seconds - 1, nanoseconds + 1_000_000_000)
    False -> #(seconds, nanoseconds)
  }

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
///
/// Returns an error if the extension is not a timestamp type (-1),
/// if the payload length is invalid, or if the decoded nanoseconds
/// are outside [0, 999_999_999].
pub fn decode(value: Value) -> Result(Timestamp, TimestampError) {
  case value {
    Extension(type_code, data) if type_code == timestamp_type_code -> {
      let size = bit_array.byte_size(data)
      case size, data {
        // Timestamp 32: 4 bytes
        4, <<seconds:32>> -> Ok(timestamp.from_unix_seconds(seconds))

        // Timestamp 64: 8 bytes
        8, <<combined:32, seconds_lower:32>> -> {
          // Extract nanoseconds (upper 30 bits) and seconds (34 bits total)
          let nanoseconds = combined / 4
          let seconds_upper = combined % 4
          let seconds = seconds_upper * 4_294_967_296 + seconds_lower
          case nanoseconds >= 0 && nanoseconds <= 999_999_999 {
            True ->
              Ok(timestamp.from_unix_seconds_and_nanoseconds(
                seconds:,
                nanoseconds:,
              ))
            False -> Error(InvalidNanoseconds(nanoseconds))
          }
        }

        // Timestamp 96: 12 bytes
        12, <<nanoseconds:32, seconds:64-signed>> ->
          case nanoseconds >= 0 && nanoseconds <= 999_999_999 {
            True ->
              Ok(timestamp.from_unix_seconds_and_nanoseconds(
                seconds:,
                nanoseconds:,
              ))
            False -> Error(InvalidNanoseconds(nanoseconds))
          }

        _, _ -> Error(InvalidDataLength(size))
      }
    }
    Extension(type_code, _) ->
      Error(NotATimestamp(expected: timestamp_type_code, got: type_code))
    _ -> Error(NotAnExtension("Expected Extension value"))
  }
}

/// Check if a Value is a timestamp extension.
pub fn is_timestamp(value: Value) -> Bool {
  case value {
    Extension(tc, _) if tc == timestamp_type_code -> True
    _ -> False
  }
}

/// Create a timestamp from Unix milliseconds.
///
/// Negative milliseconds are normalized so that nanoseconds is always
/// non-negative. For example, `from_unix_millis(-1)` produces a
/// timestamp with seconds = -1 and nanoseconds = 999_000_000.
pub fn from_unix_millis(millis: Int) -> Timestamp {
  let remainder = millis % 1000
  case remainder < 0 {
    True -> {
      let seconds = millis / 1000 - 1
      let nanoseconds = { remainder + 1000 } * 1_000_000
      timestamp.from_unix_seconds_and_nanoseconds(seconds:, nanoseconds:)
    }
    False -> {
      let seconds = millis / 1000
      let nanoseconds = remainder * 1_000_000
      timestamp.from_unix_seconds_and_nanoseconds(seconds:, nanoseconds:)
    }
  }
}

/// Convert a timestamp to Unix milliseconds (truncating sub-millisecond precision).
pub fn to_unix_millis(ts: Timestamp) -> Int {
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  seconds * 1000 + nanoseconds / 1_000_000
}
