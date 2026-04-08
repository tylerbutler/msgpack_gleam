/// MessagePack Value type representing all possible MessagePack values.
/// This is a union type that can hold any MessagePack-compatible value.
pub type Value {
  /// Nil value (null)
  Nil
  /// Boolean value
  Boolean(Bool)
  /// Integer value (covers all MessagePack integer formats)
  Integer(Int)
  /// Floating point value (covers float32 and float64)
  Float(Float)
  /// UTF-8 string value
  String(String)
  /// Binary data (raw bytes)
  Binary(BitArray)
  /// Array of values
  Array(List(Value))
  /// Map of key-value pairs (preserves ordering, keys can be any Value type)
  Map(List(#(Value, Value)))
  /// Extension type with type code (-128 to 127) and data
  Extension(type_code: Int, data: BitArray)
}

/// Returns the type name of a Value as a human-readable string.
pub fn type_name(v: Value) -> String {
  case v {
    Nil -> "Nil"
    Boolean(_) -> "Boolean"
    Integer(_) -> "Integer"
    Float(_) -> "Float"
    String(_) -> "String"
    Binary(_) -> "Binary"
    Array(_) -> "Array"
    Map(_) -> "Map"
    Extension(_, _) -> "Extension"
  }
}
