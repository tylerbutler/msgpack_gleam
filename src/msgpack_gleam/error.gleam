import gleam/int

/// Errors that can occur during MessagePack encoding.
pub type EncodeError {
  /// Integer is too large to be represented in MessagePack format
  IntegerTooLarge(Int)
  /// String is too long (exceeds 2^32 - 1 bytes)
  StringTooLong(Int)
  /// Binary data is too long (exceeds 2^32 - 1 bytes)
  BinaryTooLong(Int)
  /// Array has too many elements (exceeds 2^32 - 1)
  ArrayTooLong(Int)
  /// Map has too many entries (exceeds 2^32 - 1)
  MapTooLong(Int)
  /// Extension type code is out of valid range (-128 to 127)
  InvalidExtensionTypeCode(Int)
  /// Extension data is too long (exceeds 2^32 - 1 bytes)
  ExtensionDataTooLong(Int)
}

/// Errors that can occur during MessagePack decoding.
pub type DecodeError {
  /// Unexpected end of input
  UnexpectedEof
  /// Invalid format byte encountered
  InvalidFormat(Int)
  /// String data is not valid UTF-8
  InvalidUtf8
  /// Integer value overflows the target type
  IntegerOverflow
  /// Reserved format byte was encountered
  ReservedFormat(Int)
  /// Trailing bytes remain after decoding
  TrailingBytes(Int)
  /// Float value is NaN or Infinity, which BEAM cannot represent
  UnsupportedFloat
}

/// Format an encode error as a human-readable string.
pub fn format_encode_error(error: EncodeError) -> String {
  case error {
    IntegerTooLarge(n) ->
      "Integer too large for MessagePack: " <> int.to_string(n)
    StringTooLong(n) ->
      "String too long: " <> int.to_string(n) <> " bytes (max 4294967295)"
    BinaryTooLong(n) ->
      "Binary too long: " <> int.to_string(n) <> " bytes (max 4294967295)"
    ArrayTooLong(n) ->
      "Array too long: " <> int.to_string(n) <> " elements (max 4294967295)"
    MapTooLong(n) ->
      "Map too long: " <> int.to_string(n) <> " entries (max 4294967295)"
    InvalidExtensionTypeCode(n) ->
      "Invalid extension type code: "
      <> int.to_string(n)
      <> " (must be -128 to 127)"
    ExtensionDataTooLong(n) ->
      "Extension data too long: "
      <> int.to_string(n)
      <> " bytes (max 4294967295)"
  }
}

/// Format a decode error as a human-readable string.
pub fn format_decode_error(error: DecodeError) -> String {
  case error {
    UnexpectedEof -> "Unexpected end of input"
    InvalidFormat(b) -> "Invalid format byte: " <> int.to_string(b)
    InvalidUtf8 -> "Invalid UTF-8 in string"
    IntegerOverflow -> "Integer overflow"
    ReservedFormat(b) -> "Reserved format byte: " <> int.to_string(b)
    TrailingBytes(n) ->
      "Unexpected trailing bytes: " <> int.to_string(n) <> " bytes remaining"
    UnsupportedFloat -> "Unsupported float value (NaN or Infinity)"
  }
}
