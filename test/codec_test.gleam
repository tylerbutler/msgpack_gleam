import gleam/dict
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import msgpack_gleam
import msgpack_gleam/codec.{type Codec}
import msgpack_gleam/value
import startest/expect

// ============================================================================
// Test Types
// ============================================================================

pub type Person {
  Person(name: String, age: Int)
}

pub type User {
  User(id: Int, name: String, email: option.Option(String), tags: List(String))
}

pub type Point {
  Point(x: Float, y: Float)
}

pub type TreeNode {
  Leaf(val: Int)
  Branch(left: TreeNode, right: TreeNode)
}

// ============================================================================
// Primitive Codec Tests
// ============================================================================

pub fn bool_codec_test() {
  let c = codec.bool()

  // Encode
  codec.encode(c, True)
  |> expect.to_equal(value.Boolean(True))

  codec.encode(c, False)
  |> expect.to_equal(value.Boolean(False))

  // Decode
  codec.decode(c, value.Boolean(True))
  |> expect.to_equal(Ok(True))

  codec.decode(c, value.Boolean(False))
  |> expect.to_equal(Ok(False))

  // Decode wrong type
  let _ = codec.decode(c, value.Integer(1)) |> expect.to_be_error()
  Nil
}

pub fn int_codec_test() {
  let c = codec.int()

  // Encode
  codec.encode(c, 42)
  |> expect.to_equal(value.Integer(42))

  codec.encode(c, -100)
  |> expect.to_equal(value.Integer(-100))

  // Decode
  codec.decode(c, value.Integer(42))
  |> expect.to_equal(Ok(42))

  // Decode wrong type
  let _ = codec.decode(c, value.String("42")) |> expect.to_be_error()
  Nil
}

pub fn float_codec_test() {
  let c = codec.float()

  // Encode
  codec.encode(c, 3.14)
  |> expect.to_equal(value.Float(3.14))

  // Decode
  codec.decode(c, value.Float(3.14))
  |> expect.to_equal(Ok(3.14))

  // Decode integer as float (coercion)
  codec.decode(c, value.Integer(42))
  |> expect.to_equal(Ok(42.0))

  // Decode wrong type
  let _ = codec.decode(c, value.String("3.14")) |> expect.to_be_error()
  Nil
}

pub fn float_strict_codec_test() {
  let c = codec.float_strict()

  // Decode float
  codec.decode(c, value.Float(3.14))
  |> expect.to_equal(Ok(3.14))

  // Decode integer fails (no coercion)
  let _ = codec.decode(c, value.Integer(42)) |> expect.to_be_error()
  Nil
}

pub fn string_codec_test() {
  let c = codec.string()

  // Encode
  codec.encode(c, "hello")
  |> expect.to_equal(value.String("hello"))

  // Decode
  codec.decode(c, value.String("world"))
  |> expect.to_equal(Ok("world"))

  // Decode wrong type
  let _ = codec.decode(c, value.Integer(42)) |> expect.to_be_error()
  Nil
}

pub fn binary_codec_test() {
  let c = codec.binary()

  // Encode
  codec.encode(c, <<1, 2, 3>>)
  |> expect.to_equal(value.Binary(<<1, 2, 3>>))

  // Decode
  codec.decode(c, value.Binary(<<4, 5, 6>>))
  |> expect.to_equal(Ok(<<4, 5, 6>>))
}

// ============================================================================
// Composite Codec Tests
// ============================================================================

pub fn nullable_codec_test() {
  let c = codec.nullable(codec.string())

  // Encode Some
  codec.encode(c, Some("hello"))
  |> expect.to_equal(value.String("hello"))

  // Encode None
  codec.encode(c, None)
  |> expect.to_equal(value.Nil)

  // Decode Some
  codec.decode(c, value.String("hello"))
  |> expect.to_equal(Ok(Some("hello")))

  // Decode None
  codec.decode(c, value.Nil)
  |> expect.to_equal(Ok(None))
}

pub fn list_codec_test() {
  let c = codec.list(codec.int())

  // Encode
  codec.encode(c, [1, 2, 3])
  |> expect.to_equal(
    value.Array([value.Integer(1), value.Integer(2), value.Integer(3)]),
  )

  // Decode
  codec.decode(c, value.Array([value.Integer(4), value.Integer(5)]))
  |> expect.to_equal(Ok([4, 5]))

  // Decode empty list
  codec.decode(c, value.Array([]))
  |> expect.to_equal(Ok([]))

  // Decode wrong element type
  let _ =
    codec.decode(c, value.Array([value.Integer(1), value.String("two")]))
    |> expect.to_be_error()
  Nil
}

pub fn string_dict_codec_test() {
  let c = codec.string_dict(codec.int())

  // Encode
  let d = dict.from_list([#("a", 1), #("b", 2)])
  let encoded = codec.encode(c, d)

  // Decode back
  let assert Ok(decoded) = codec.decode(c, encoded)
  dict.get(decoded, "a")
  |> expect.to_equal(Ok(1))
  dict.get(decoded, "b")
  |> expect.to_equal(Ok(2))
}

pub fn dict_codec_test() {
  let c = codec.dict(codec.int(), codec.string())

  // Encode
  let d = dict.from_list([#(1, "one"), #(2, "two")])
  let encoded = codec.encode(c, d)

  // Decode back
  let assert Ok(decoded) = codec.decode(c, encoded)
  dict.get(decoded, 1)
  |> expect.to_equal(Ok("one"))
  dict.get(decoded, 2)
  |> expect.to_equal(Ok("two"))
}

// ============================================================================
// Object Codec Tests
// ============================================================================

fn person_codec() -> Codec(Person) {
  codec.object2(
    constructor: Person,
    field1: codec.field("name", codec.string(), fn(p: Person) { p.name }),
    field2: codec.field("age", codec.int(), fn(p: Person) { p.age }),
  )
}

pub fn object2_codec_test() {
  let c = person_codec()
  let person = Person("Alice", 30)

  // Encode
  let encoded = codec.encode(c, person)
  encoded
  |> expect.to_equal(
    value.Map([
      #(value.String("name"), value.String("Alice")),
      #(value.String("age"), value.Integer(30)),
    ]),
  )

  // Decode
  codec.decode(c, encoded)
  |> expect.to_equal(Ok(person))
}

fn user_codec() -> Codec(User) {
  codec.object4(
    constructor: User,
    field1: codec.field("id", codec.int(), fn(u: User) { u.id }),
    field2: codec.field("name", codec.string(), fn(u: User) { u.name }),
    field3: codec.field("email", codec.nullable(codec.string()), fn(u: User) {
      u.email
    }),
    field4: codec.field("tags", codec.list(codec.string()), fn(u: User) {
      u.tags
    }),
  )
}

pub fn object4_codec_test() {
  let c = user_codec()
  let user = User(1, "Bob", Some("bob@example.com"), ["admin", "active"])

  // Round-trip
  let encoded = codec.encode(c, user)
  codec.decode(c, encoded)
  |> expect.to_equal(Ok(user))

  // With None email
  let user2 = User(2, "Charlie", None, [])
  let encoded2 = codec.encode(c, user2)
  codec.decode(c, encoded2)
  |> expect.to_equal(Ok(user2))
}

pub fn missing_field_error_test() {
  let c = person_codec()

  // Missing 'age' field
  let v = value.Map([#(value.String("name"), value.String("Alice"))])
  let result = codec.decode(c, v)
  let _ = result |> expect.to_be_error()

  // Check error message
  let assert Error(err) = result
  codec.format_error(err)
  |> expect.to_equal("missing field \"age\"")
}

pub fn field_type_error_test() {
  let c = person_codec()

  // Wrong type for 'age'
  let v =
    value.Map([
      #(value.String("name"), value.String("Alice")),
      #(value.String("age"), value.String("thirty")),
    ])
  let result = codec.decode(c, v)
  let _ = result |> expect.to_be_error()

  // Check error message includes path
  let assert Error(err) = result
  let error_str = codec.format_error(err)
  // Should mention the field name
  expect.to_be_true(string.contains(error_str, ".age"))
}

// ============================================================================
// Tuple Codec Tests
// ============================================================================

pub fn tuple2_codec_test() {
  let c = codec.tuple2(codec.string(), codec.int())

  // Encode
  codec.encode(c, #("hello", 42))
  |> expect.to_equal(value.Array([value.String("hello"), value.Integer(42)]))

  // Decode
  codec.decode(c, value.Array([value.String("world"), value.Integer(100)]))
  |> expect.to_equal(Ok(#("world", 100)))

  // Wrong length
  let _ =
    codec.decode(c, value.Array([value.String("only one")]))
    |> expect.to_be_error()
  Nil
}

pub fn tuple3_codec_test() {
  let c = codec.tuple3(codec.int(), codec.int(), codec.int())

  // Round-trip
  let tuple = #(1, 2, 3)
  let encoded = codec.encode(c, tuple)
  codec.decode(c, encoded)
  |> expect.to_equal(Ok(tuple))
}

// ============================================================================
// Combinator Tests
// ============================================================================

pub fn map_codec_test() {
  // Map Point to/from tuple
  let point_codec =
    codec.tuple2(codec.float(), codec.float())
    |> codec.map(fn(p: Point) { #(p.x, p.y) }, fn(t) { Point(t.0, t.1) })

  let point = Point(1.5, 2.5)

  // Round-trip
  let encoded = codec.encode(point_codec, point)
  codec.decode(point_codec, encoded)
  |> expect.to_equal(Ok(point))
}

pub fn one_of_codec_test() {
  // Accept either int or string-encoded int
  let flexible_int =
    codec.one_of([
      codec.int(),
      codec.string()
        |> codec.try_map(fn(i) { int.to_string(i) }, fn(s) {
          case int.parse(s) {
            Ok(i) -> Ok(i)
            Error(_) -> Error(codec.CustomError("Not a valid integer string"))
          }
        }),
    ])

  // Decode int
  codec.decode(flexible_int, value.Integer(42))
  |> expect.to_equal(Ok(42))

  // Decode string
  codec.decode(flexible_int, value.String("123"))
  |> expect.to_equal(Ok(123))

  // Invalid string
  let _ =
    codec.decode(flexible_int, value.String("not a number"))
    |> expect.to_be_error()
  Nil
}

pub fn with_default_codec_test() {
  let c = codec.with_default(codec.int(), 0)

  // Successful decode
  codec.decode(c, value.Integer(42))
  |> expect.to_equal(Ok(42))

  // Failed decode uses default
  codec.decode(c, value.String("not an int"))
  |> expect.to_equal(Ok(0))

  // Nil uses default
  codec.decode(c, value.Nil)
  |> expect.to_equal(Ok(0))
}

// ============================================================================
// Constrained Codec Tests
// ============================================================================

pub fn int_range_codec_test() {
  let c = codec.int_range(0, 100)

  // In range
  codec.decode(c, value.Integer(50))
  |> expect.to_equal(Ok(50))

  codec.decode(c, value.Integer(0))
  |> expect.to_equal(Ok(0))

  codec.decode(c, value.Integer(100))
  |> expect.to_equal(Ok(100))

  // Out of range
  let _ = codec.decode(c, value.Integer(-1)) |> expect.to_be_error()
  let _ = codec.decode(c, value.Integer(101)) |> expect.to_be_error()
  Nil
}

pub fn non_empty_string_codec_test() {
  let c = codec.non_empty_string()

  // Non-empty
  codec.decode(c, value.String("hello"))
  |> expect.to_equal(Ok("hello"))

  // Empty fails
  let _ = codec.decode(c, value.String("")) |> expect.to_be_error()
  Nil
}

pub fn non_empty_list_codec_test() {
  let c = codec.non_empty_list(codec.int())

  // Non-empty
  codec.decode(c, value.Array([value.Integer(1), value.Integer(2)]))
  |> expect.to_equal(Ok([1, 2]))

  // Empty fails
  let _ = codec.decode(c, value.Array([])) |> expect.to_be_error()
  Nil
}

// ============================================================================
// Lazy Codec Tests (Recursive Types)
// ============================================================================

// For sum types (variants), we need a custom codec that dispatches based on the variant.
// This is a tagged union approach using a "type" field.
fn tree_codec() -> Codec(TreeNode) {
  codec.custom(
    // Encoder: dispatch based on variant
    fn(node) {
      case node {
        Leaf(v) ->
          value.Map([
            #(value.String("type"), value.String("leaf")),
            #(value.String("value"), value.Integer(v)),
          ])
        Branch(l, r) ->
          value.Map([
            #(value.String("type"), value.String("branch")),
            #(value.String("left"), codec.encode(codec.lazy(tree_codec), l)),
            #(value.String("right"), codec.encode(codec.lazy(tree_codec), r)),
          ])
      }
    },
    // Decoder: check "type" field to determine variant
    fn(v) {
      case v {
        value.Map(pairs) -> {
          use tag <- result.try(find_string_field(pairs, "type"))
          case tag {
            "leaf" -> result.map(find_int_field(pairs, "value"), Leaf)
            "branch" -> {
              let decoder = codec.lazy(tree_codec)
              use left_val <- result.try(find_value_field(pairs, "left"))
              use right_val <- result.try(find_value_field(pairs, "right"))
              use left <- result.try(
                codec.decode(decoder, left_val)
                |> result.map_error(codec.FieldError("left", _)),
              )
              use right <- result.try(
                codec.decode(decoder, right_val)
                |> result.map_error(codec.FieldError("right", _)),
              )
              Ok(Branch(left, right))
            }
            other -> Error(codec.CustomError("Unknown type: " <> other))
          }
        }
        other -> Error(codec.TypeMismatch("Map", value.type_name(other)))
      }
    },
  )
}

fn find_string_field(
  pairs: List(#(value.Value, value.Value)),
  name: String,
) -> Result(String, codec.CodecDecodeError) {
  use v <- result.try(find_value_field(pairs, name))
  case v {
    value.String(s) -> Ok(s)
    other -> Error(codec.TypeMismatch("String", value.type_name(other)))
  }
}

fn find_int_field(
  pairs: List(#(value.Value, value.Value)),
  name: String,
) -> Result(Int, codec.CodecDecodeError) {
  use v <- result.try(find_value_field(pairs, name))
  case v {
    value.Integer(i) -> Ok(i)
    other -> Error(codec.TypeMismatch("Integer", value.type_name(other)))
  }
}


fn find_value_field(
  pairs: List(#(value.Value, value.Value)),
  name: String,
) -> Result(value.Value, codec.CodecDecodeError) {
  case pairs {
    [] -> Error(codec.MissingField(name))
    [#(value.String(k), v), ..rest] ->
      case k == name {
        True -> Ok(v)
        False -> find_value_field(rest, name)
      }
    [_, ..rest] -> find_value_field(rest, name)
  }
}

pub fn recursive_codec_test() {
  let c = tree_codec()

  // Simple leaf
  let leaf = Leaf(42)
  let encoded_leaf = codec.encode(c, leaf)
  codec.decode(c, encoded_leaf)
  |> expect.to_equal(Ok(leaf))

  // Branch with leaves
  let tree = Branch(Leaf(1), Leaf(2))
  let encoded_tree = codec.encode(c, tree)
  codec.decode(c, encoded_tree)
  |> expect.to_equal(Ok(tree))

  // Nested branches
  let nested = Branch(Branch(Leaf(1), Leaf(2)), Leaf(3))
  let encoded_nested = codec.encode(c, nested)
  codec.decode(c, encoded_nested)
  |> expect.to_equal(Ok(nested))
}

// ============================================================================
// Full Round-Trip with MessagePack Binary
// ============================================================================

pub fn full_roundtrip_test() {
  let c = user_codec()
  let user = User(42, "Test User", Some("test@example.com"), ["tag1", "tag2"])

  // Encode to Value
  let v = codec.encode(c, user)

  // Pack to binary
  let assert Ok(bytes) = msgpack_gleam.pack(v)

  // Unpack from binary
  let assert Ok(decoded_value) = msgpack_gleam.unpack_exact(bytes)

  // Decode from Value
  let assert Ok(decoded_user) = codec.decode(c, decoded_value)

  decoded_user
  |> expect.to_equal(user)
}

pub fn nested_structure_roundtrip_test() {
  // List of users
  let c = codec.list(user_codec())
  let users = [
    User(1, "Alice", Some("alice@example.com"), ["admin"]),
    User(2, "Bob", None, []),
    User(3, "Charlie", Some("charlie@example.com"), ["user", "beta"]),
  ]

  // Full round-trip
  let v = codec.encode(c, users)
  let assert Ok(bytes) = msgpack_gleam.pack(v)
  let assert Ok(decoded_value) = msgpack_gleam.unpack_exact(bytes)
  let assert Ok(decoded_users) = codec.decode(c, decoded_value)

  decoded_users
  |> expect.to_equal(users)
}

// ============================================================================
// Robustness & Edge-Case Tests
// ============================================================================

pub fn object_extra_fields_ignored_test() {
  let c = person_codec()
  let v =
    value.Map([
      #(value.String("name"), value.String("Alice")),
      #(value.String("age"), value.Integer(30)),
      #(value.String("height"), value.Float(1.65)),
    ])
  codec.decode(c, v) |> expect.to_equal(Ok(Person("Alice", 30)))
}

pub fn object_field_order_independence_test() {
  let c = person_codec()
  let v =
    value.Map([
      #(value.String("age"), value.Integer(30)),
      #(value.String("name"), value.String("Alice")),
    ])
  codec.decode(c, v) |> expect.to_equal(Ok(Person("Alice", 30)))
}

pub fn string_dict_non_string_key_error_test() {
  let c = codec.string_dict(codec.int())
  let v = value.Map([#(value.Integer(1), value.Integer(42))])
  let assert Error(_) = codec.decode(c, v)
  Nil
}

pub fn dict_key_decode_error_test() {
  let c = codec.dict(codec.int(), codec.string())
  let v = value.Map([#(value.String("not-an-int"), value.String("hello"))])
  let assert Error(_) = codec.decode(c, v)
  Nil
}

pub fn dict_value_decode_error_test() {
  let c = codec.dict(codec.string(), codec.int())
  let v = value.Map([#(value.String("key"), value.String("not-an-int"))])
  let assert Error(_) = codec.decode(c, v)
  Nil
}

pub fn nullable_nil_decode_test() {
  let c = codec.nullable(codec.string())
  codec.decode(c, value.Nil) |> expect.to_equal(Ok(option.None))
}

pub fn nullable_value_decode_test() {
  let c = codec.nullable(codec.string())
  codec.decode(c, value.String("hello"))
  |> expect.to_equal(Ok(option.Some("hello")))
}

pub fn list_empty_decode_test() {
  let c = codec.list(codec.int())
  codec.decode(c, value.Array([])) |> expect.to_equal(Ok([]))
}

pub fn non_empty_string_empty_error_test() {
  let c = codec.non_empty_string()
  let assert Error(codec.OutOfRange(_)) = codec.decode(c, value.String(""))
  Nil
}

pub fn int_range_at_min_test() {
  let c = codec.int_range(0, 100)
  codec.decode(c, value.Integer(0)) |> expect.to_equal(Ok(0))
}

pub fn int_range_at_max_test() {
  let c = codec.int_range(0, 100)
  codec.decode(c, value.Integer(100)) |> expect.to_equal(Ok(100))
}

pub fn int_range_below_min_test() {
  let c = codec.int_range(0, 100)
  let assert Error(codec.OutOfRange(_)) = codec.decode(c, value.Integer(-1))
  Nil
}

pub fn int_range_above_max_test() {
  let c = codec.int_range(0, 100)
  let assert Error(codec.OutOfRange(_)) = codec.decode(c, value.Integer(101))
  Nil
}

// ============================================================================
// Additional Test Types
// ============================================================================

type Wrapper {
  Wrapper(val: Int)
}

type Triple {
  Triple(a: String, b: Int, c: Bool)
}

type BigRecord {
  BigRecord(
    f1: String,
    f2: Int,
    f3: Bool,
    f4: Float,
    f5: String,
    f6: Int,
    f7: Bool,
    f8: String,
  )
}

// ============================================================================
// Extension Codec Tests
// ============================================================================

pub fn extension_codec_encode_test() {
  let c = codec.extension(5)
  codec.encode(c, <<1, 2, 3>>)
  |> expect.to_equal(value.Extension(5, <<1, 2, 3>>))
}

pub fn extension_codec_decode_test() {
  let c = codec.extension(5)
  codec.decode(c, value.Extension(5, <<4, 5>>)) |> expect.to_equal(Ok(<<4, 5>>))
}

pub fn extension_codec_wrong_type_test() {
  let c = codec.extension(5)
  let assert Error(codec.ExtensionTypeMismatch(5, 7)) =
    codec.decode(c, value.Extension(7, <<>>))
  Nil
}

pub fn extension_codec_non_extension_test() {
  let c = codec.extension(5)
  let assert Error(codec.TypeMismatch(_, _)) =
    codec.decode(c, value.Integer(42))
  Nil
}

pub fn any_extension_codec_encode_test() {
  let c = codec.any_extension()
  codec.encode(c, #(3, <<0xAB>>))
  |> expect.to_equal(value.Extension(3, <<0xAB>>))
}

pub fn any_extension_codec_decode_test() {
  let c = codec.any_extension()
  codec.decode(c, value.Extension(3, <<0xAB>>))
  |> expect.to_equal(Ok(#(3, <<0xAB>>)))
}

pub fn any_extension_codec_non_extension_test() {
  let c = codec.any_extension()
  let assert Error(codec.TypeMismatch(_, _)) =
    codec.decode(c, value.String("x"))
  Nil
}

// ============================================================================
// Object Boundary Tests (object1, object3, object8)
// ============================================================================

pub fn object1_encode_decode_test() {
  let c =
    codec.object1(
      constructor: Wrapper,
      field1: codec.field("val", codec.int(), fn(w: Wrapper) { w.val }),
    )
  let w = Wrapper(42)
  let encoded = codec.encode(c, w)
  codec.decode(c, encoded) |> expect.to_equal(Ok(w))
}

pub fn object3_encode_decode_test() {
  let c =
    codec.object3(
      constructor: Triple,
      field1: codec.field("a", codec.string(), fn(t: Triple) { t.a }),
      field2: codec.field("b", codec.int(), fn(t: Triple) { t.b }),
      field3: codec.field("c", codec.bool(), fn(t: Triple) { t.c }),
    )
  let t = Triple("hello", 42, True)
  let encoded = codec.encode(c, t)
  codec.decode(c, encoded) |> expect.to_equal(Ok(t))
}

pub fn object8_encode_decode_test() {
  let c =
    codec.object8(
      constructor: BigRecord,
      field1: codec.field("f1", codec.string(), fn(r: BigRecord) { r.f1 }),
      field2: codec.field("f2", codec.int(), fn(r: BigRecord) { r.f2 }),
      field3: codec.field("f3", codec.bool(), fn(r: BigRecord) { r.f3 }),
      field4: codec.field("f4", codec.float(), fn(r: BigRecord) { r.f4 }),
      field5: codec.field("f5", codec.string(), fn(r: BigRecord) { r.f5 }),
      field6: codec.field("f6", codec.int(), fn(r: BigRecord) { r.f6 }),
      field7: codec.field("f7", codec.bool(), fn(r: BigRecord) { r.f7 }),
      field8: codec.field("f8", codec.string(), fn(r: BigRecord) { r.f8 }),
    )
  let r = BigRecord("a", 1, True, 2.5, "b", 3, False, "c")
  let encoded = codec.encode(c, r)
  codec.decode(c, encoded) |> expect.to_equal(Ok(r))
}

pub fn object8_field_ordering_test() {
  let c =
    codec.object8(
      constructor: BigRecord,
      field1: codec.field("f1", codec.string(), fn(r: BigRecord) { r.f1 }),
      field2: codec.field("f2", codec.int(), fn(r: BigRecord) { r.f2 }),
      field3: codec.field("f3", codec.bool(), fn(r: BigRecord) { r.f3 }),
      field4: codec.field("f4", codec.float(), fn(r: BigRecord) { r.f4 }),
      field5: codec.field("f5", codec.string(), fn(r: BigRecord) { r.f5 }),
      field6: codec.field("f6", codec.int(), fn(r: BigRecord) { r.f6 }),
      field7: codec.field("f7", codec.bool(), fn(r: BigRecord) { r.f7 }),
      field8: codec.field("f8", codec.string(), fn(r: BigRecord) { r.f8 }),
    )
  let r = BigRecord("alpha", 100, True, 3.14, "beta", 200, False, "gamma")
  let encoded = codec.encode(c, r)
  let assert Ok(decoded) = codec.decode(c, encoded)
  decoded.f1 |> expect.to_equal("alpha")
  decoded.f2 |> expect.to_equal(100)
  decoded.f3 |> expect.to_equal(True)
  decoded.f5 |> expect.to_equal("beta")
  decoded.f6 |> expect.to_equal(200)
  decoded.f7 |> expect.to_equal(False)
  decoded.f8 |> expect.to_equal("gamma")
}

// ============================================================================
// Misc Codec Tests (succeed, fail, raw_value, tuple4)
// ============================================================================

pub fn succeed_codec_test() {
  let c = codec.succeed(42)
  codec.decode(c, value.Nil) |> expect.to_equal(Ok(42))
  codec.decode(c, value.String("anything")) |> expect.to_equal(Ok(42))
}

pub fn fail_codec_test() {
  let c = codec.fail("nope")
  let assert Error(codec.CustomError("nope")) = codec.decode(c, value.Nil)
  Nil
}

pub fn raw_value_encode_test() {
  let c = codec.raw_value()
  let v = value.Array([value.Integer(1), value.String("x")])
  codec.encode(c, v) |> expect.to_equal(v)
}

pub fn raw_value_decode_test() {
  let c = codec.raw_value()
  let v = value.Array([value.Integer(1), value.String("x")])
  codec.decode(c, v) |> expect.to_equal(Ok(v))
}

pub fn tuple4_encode_decode_test() {
  let c = codec.tuple4(codec.string(), codec.int(), codec.bool(), codec.float())
  let t = #("hello", 42, True, 3.14)
  let encoded = codec.encode(c, t)
  codec.decode(c, encoded) |> expect.to_equal(Ok(t))
}

// ============================================================================
// format_error Tests
// ============================================================================

pub fn format_error_type_mismatch_test() {
  codec.format_error(codec.TypeMismatch("String", "Integer"))
  |> expect.to_equal("expected String, got Integer")
}

pub fn format_error_missing_field_test() {
  codec.format_error(codec.MissingField("name"))
  |> expect.to_equal("missing field \"name\"")
}

pub fn format_error_index_error_test() {
  let err = codec.IndexError(2, codec.TypeMismatch("String", "Integer"))
  codec.format_error(err)
  |> expect.to_equal("at $[2]: expected String, got Integer")
}

pub fn format_error_extension_type_mismatch_test() {
  codec.format_error(codec.ExtensionTypeMismatch(5, 7))
  |> expect.to_equal("expected extension type 5, got 7")
}

pub fn format_error_out_of_range_test() {
  codec.format_error(codec.OutOfRange("Value must be 0-100"))
  |> expect.to_equal("Value must be 0-100")
}

pub fn format_error_custom_error_test() {
  codec.format_error(codec.CustomError("something went wrong"))
  |> expect.to_equal("something went wrong")
}

pub fn format_error_all_failed_test() {
  let err =
    codec.AllFailed([
      codec.TypeMismatch("String", "Integer"),
      codec.MissingField("x"),
    ])
  codec.format_error(err)
  |> expect.to_equal(
    "all alternatives failed: [expected String, got Integer, missing field \"x\"]",
  )
}

pub fn format_error_nested_field_error_test() {
  let err =
    codec.FieldError(
      "users",
      codec.IndexError(
        0,
        codec.FieldError("name", codec.TypeMismatch("String", "Integer")),
      ),
    )
  codec.format_error(err)
  |> expect.to_equal("at $.users[0].name: expected String, got Integer")
}

// ============================================================================
// Nil Codec Tests
// ============================================================================

pub fn nil_codec_encode_test() {
  let c = codec.nil()
  codec.encode(c, Nil)
  |> expect.to_equal(value.Nil)
}

pub fn nil_codec_decode_test() {
  let c = codec.nil()
  codec.decode(c, value.Nil)
  |> expect.to_equal(Ok(Nil))
}

pub fn nil_codec_decode_error_test() {
  let c = codec.nil()
  let assert Error(_) = codec.decode(c, value.Integer(42))
  Nil
}
