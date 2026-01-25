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
}
