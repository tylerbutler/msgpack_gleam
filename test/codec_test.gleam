import gleam/dict
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import msgpack_gleam
import msgpack_gleam/codec.{type Codec}
import msgpack_gleam/value

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
  |> should.equal(value.Boolean(True))

  codec.encode(c, False)
  |> should.equal(value.Boolean(False))

  // Decode
  codec.decode(c, value.Boolean(True))
  |> should.equal(Ok(True))

  codec.decode(c, value.Boolean(False))
  |> should.equal(Ok(False))

  // Decode wrong type
  codec.decode(c, value.Integer(1))
  |> should.be_error()
}

pub fn int_codec_test() {
  let c = codec.int()

  // Encode
  codec.encode(c, 42)
  |> should.equal(value.Integer(42))

  codec.encode(c, -100)
  |> should.equal(value.Integer(-100))

  // Decode
  codec.decode(c, value.Integer(42))
  |> should.equal(Ok(42))

  // Decode wrong type
  codec.decode(c, value.String("42"))
  |> should.be_error()
}

pub fn float_codec_test() {
  let c = codec.float()

  // Encode
  codec.encode(c, 3.14)
  |> should.equal(value.Float(3.14))

  // Decode
  codec.decode(c, value.Float(3.14))
  |> should.equal(Ok(3.14))

  // Decode integer as float (coercion)
  codec.decode(c, value.Integer(42))
  |> should.equal(Ok(42.0))

  // Decode wrong type
  codec.decode(c, value.String("3.14"))
  |> should.be_error()
}

pub fn float_strict_codec_test() {
  let c = codec.float_strict()

  // Decode float
  codec.decode(c, value.Float(3.14))
  |> should.equal(Ok(3.14))

  // Decode integer fails (no coercion)
  codec.decode(c, value.Integer(42))
  |> should.be_error()
}

pub fn string_codec_test() {
  let c = codec.string()

  // Encode
  codec.encode(c, "hello")
  |> should.equal(value.String("hello"))

  // Decode
  codec.decode(c, value.String("world"))
  |> should.equal(Ok("world"))

  // Decode wrong type
  codec.decode(c, value.Integer(42))
  |> should.be_error()
}

pub fn binary_codec_test() {
  let c = codec.binary()

  // Encode
  codec.encode(c, <<1, 2, 3>>)
  |> should.equal(value.Binary(<<1, 2, 3>>))

  // Decode
  codec.decode(c, value.Binary(<<4, 5, 6>>))
  |> should.equal(Ok(<<4, 5, 6>>))
}

// ============================================================================
// Composite Codec Tests
// ============================================================================

pub fn nullable_codec_test() {
  let c = codec.nullable(codec.string())

  // Encode Some
  codec.encode(c, Some("hello"))
  |> should.equal(value.String("hello"))

  // Encode None
  codec.encode(c, None)
  |> should.equal(value.Nil)

  // Decode Some
  codec.decode(c, value.String("hello"))
  |> should.equal(Ok(Some("hello")))

  // Decode None
  codec.decode(c, value.Nil)
  |> should.equal(Ok(None))
}

pub fn list_codec_test() {
  let c = codec.list(codec.int())

  // Encode
  codec.encode(c, [1, 2, 3])
  |> should.equal(
    value.Array([value.Integer(1), value.Integer(2), value.Integer(3)]),
  )

  // Decode
  codec.decode(c, value.Array([value.Integer(4), value.Integer(5)]))
  |> should.equal(Ok([4, 5]))

  // Decode empty list
  codec.decode(c, value.Array([]))
  |> should.equal(Ok([]))

  // Decode wrong element type
  codec.decode(c, value.Array([value.Integer(1), value.String("two")]))
  |> should.be_error()
}

pub fn string_dict_codec_test() {
  let c = codec.string_dict(codec.int())

  // Encode
  let d = dict.from_list([#("a", 1), #("b", 2)])
  let encoded = codec.encode(c, d)

  // Decode back
  let assert Ok(decoded) = codec.decode(c, encoded)
  dict.get(decoded, "a")
  |> should.equal(Ok(1))
  dict.get(decoded, "b")
  |> should.equal(Ok(2))
}

pub fn dict_codec_test() {
  let c = codec.dict(codec.int(), codec.string())

  // Encode
  let d = dict.from_list([#(1, "one"), #(2, "two")])
  let encoded = codec.encode(c, d)

  // Decode back
  let assert Ok(decoded) = codec.decode(c, encoded)
  dict.get(decoded, 1)
  |> should.equal(Ok("one"))
  dict.get(decoded, 2)
  |> should.equal(Ok("two"))
}

// ============================================================================
// Object Codec Tests
// ============================================================================

fn person_codec() -> Codec(Person) {
  codec.object2(
    Person,
    codec.field("name", codec.string(), fn(p: Person) { p.name }),
    codec.field("age", codec.int(), fn(p: Person) { p.age }),
  )
}

pub fn object2_codec_test() {
  let c = person_codec()
  let person = Person("Alice", 30)

  // Encode
  let encoded = codec.encode(c, person)
  encoded
  |> should.equal(
    value.Map([
      #(value.String("name"), value.String("Alice")),
      #(value.String("age"), value.Integer(30)),
    ]),
  )

  // Decode
  codec.decode(c, encoded)
  |> should.equal(Ok(person))
}

fn user_codec() -> Codec(User) {
  codec.object4(
    User,
    codec.field("id", codec.int(), fn(u: User) { u.id }),
    codec.field("name", codec.string(), fn(u: User) { u.name }),
    codec.field("email", codec.nullable(codec.string()), fn(u: User) { u.email }),
    codec.field("tags", codec.list(codec.string()), fn(u: User) { u.tags }),
  )
}

pub fn object4_codec_test() {
  let c = user_codec()
  let user = User(1, "Bob", Some("bob@example.com"), ["admin", "active"])

  // Round-trip
  let encoded = codec.encode(c, user)
  codec.decode(c, encoded)
  |> should.equal(Ok(user))

  // With None email
  let user2 = User(2, "Charlie", None, [])
  let encoded2 = codec.encode(c, user2)
  codec.decode(c, encoded2)
  |> should.equal(Ok(user2))
}

pub fn missing_field_error_test() {
  let c = person_codec()

  // Missing 'age' field
  let v = value.Map([#(value.String("name"), value.String("Alice"))])
  let result = codec.decode(c, v)
  result
  |> should.be_error()

  // Check error message
  let assert Error(err) = result
  codec.format_error(err)
  |> should.equal("missing field \"age\"")
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
  result
  |> should.be_error()

  // Check error message includes path
  let assert Error(err) = result
  let error_str = codec.format_error(err)
  // Should mention the field name
  should.be_true(string.contains(error_str, ".age"))
}

// ============================================================================
// Tuple Codec Tests
// ============================================================================

pub fn tuple2_codec_test() {
  let c = codec.tuple2(codec.string(), codec.int())

  // Encode
  codec.encode(c, #("hello", 42))
  |> should.equal(value.Array([value.String("hello"), value.Integer(42)]))

  // Decode
  codec.decode(c, value.Array([value.String("world"), value.Integer(100)]))
  |> should.equal(Ok(#("world", 100)))

  // Wrong length
  codec.decode(c, value.Array([value.String("only one")]))
  |> should.be_error()
}

pub fn tuple3_codec_test() {
  let c = codec.tuple3(codec.int(), codec.int(), codec.int())

  // Round-trip
  let tuple = #(1, 2, 3)
  let encoded = codec.encode(c, tuple)
  codec.decode(c, encoded)
  |> should.equal(Ok(tuple))
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
  |> should.equal(Ok(point))
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
  |> should.equal(Ok(42))

  // Decode string
  codec.decode(flexible_int, value.String("123"))
  |> should.equal(Ok(123))

  // Invalid string
  codec.decode(flexible_int, value.String("not a number"))
  |> should.be_error()
}

pub fn with_default_codec_test() {
  let c = codec.with_default(codec.int(), 0)

  // Successful decode
  codec.decode(c, value.Integer(42))
  |> should.equal(Ok(42))

  // Failed decode uses default
  codec.decode(c, value.String("not an int"))
  |> should.equal(Ok(0))

  // Nil uses default
  codec.decode(c, value.Nil)
  |> should.equal(Ok(0))
}

// ============================================================================
// Constrained Codec Tests
// ============================================================================

pub fn int_range_codec_test() {
  let c = codec.int_range(0, 100)

  // In range
  codec.decode(c, value.Integer(50))
  |> should.equal(Ok(50))

  codec.decode(c, value.Integer(0))
  |> should.equal(Ok(0))

  codec.decode(c, value.Integer(100))
  |> should.equal(Ok(100))

  // Out of range
  codec.decode(c, value.Integer(-1))
  |> should.be_error()

  codec.decode(c, value.Integer(101))
  |> should.be_error()
}

pub fn non_empty_string_codec_test() {
  let c = codec.non_empty_string()

  // Non-empty
  codec.decode(c, value.String("hello"))
  |> should.equal(Ok("hello"))

  // Empty fails
  codec.decode(c, value.String(""))
  |> should.be_error()
}

pub fn non_empty_list_codec_test() {
  let c = codec.non_empty_list(codec.int())

  // Non-empty
  codec.decode(c, value.Array([value.Integer(1), value.Integer(2)]))
  |> should.equal(Ok([1, 2]))

  // Empty fails
  codec.decode(c, value.Array([]))
  |> should.be_error()
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
          // Find the type field
          case find_string_field(pairs, "type") {
            Ok("leaf") -> {
              case find_int_field(pairs, "value") {
                Ok(val) -> Ok(Leaf(val))
                Error(e) -> Error(e)
              }
            }
            Ok("branch") -> {
              case
                find_value_field(pairs, "left"),
                find_value_field(pairs, "right")
              {
                Ok(left_val), Ok(right_val) -> {
                  let decoder = codec.lazy(tree_codec)
                  case
                    codec.decode(decoder, left_val),
                    codec.decode(decoder, right_val)
                  {
                    Ok(left), Ok(right) -> Ok(Branch(left, right))
                    Error(e), _ -> Error(codec.FieldError("left", e))
                    _, Error(e) -> Error(codec.FieldError("right", e))
                  }
                }
                Error(e), _ -> Error(e)
                _, Error(e) -> Error(e)
              }
            }
            Ok(other) -> Error(codec.CustomError("Unknown type: " <> other))
            Error(e) -> Error(e)
          }
        }
        other -> Error(codec.TypeMismatch("Map", value_type_name(other)))
      }
    },
  )
}

fn find_string_field(
  pairs: List(#(value.Value, value.Value)),
  name: String,
) -> Result(String, codec.DecodeError) {
  case pairs {
    [] -> Error(codec.MissingField(name))
    [#(value.String(k), value.String(v)), ..rest] ->
      case k == name {
        True -> Ok(v)
        False -> find_string_field(rest, name)
      }
    [#(value.String(k), other), ..rest] ->
      case k == name {
        True -> Error(codec.TypeMismatch("String", value_type_name(other)))
        False -> find_string_field(rest, name)
      }
    [_, ..rest] -> find_string_field(rest, name)
  }
}

fn find_int_field(
  pairs: List(#(value.Value, value.Value)),
  name: String,
) -> Result(Int, codec.DecodeError) {
  case pairs {
    [] -> Error(codec.MissingField(name))
    [#(value.String(k), value.Integer(v)), ..rest] ->
      case k == name {
        True -> Ok(v)
        False -> find_int_field(rest, name)
      }
    [#(value.String(k), other), ..rest] ->
      case k == name {
        True -> Error(codec.TypeMismatch("Integer", value_type_name(other)))
        False -> find_int_field(rest, name)
      }
    [_, ..rest] -> find_int_field(rest, name)
  }
}

fn find_value_field(
  pairs: List(#(value.Value, value.Value)),
  name: String,
) -> Result(value.Value, codec.DecodeError) {
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

fn value_type_name(v: value.Value) -> String {
  case v {
    value.Nil -> "Nil"
    value.Boolean(_) -> "Boolean"
    value.Integer(_) -> "Integer"
    value.Float(_) -> "Float"
    value.String(_) -> "String"
    value.Binary(_) -> "Binary"
    value.Array(_) -> "Array"
    value.Map(_) -> "Map"
    value.Extension(_, _) -> "Extension"
  }
}

pub fn recursive_codec_test() {
  let c = tree_codec()

  // Simple leaf
  let leaf = Leaf(42)
  let encoded_leaf = codec.encode(c, leaf)
  codec.decode(c, encoded_leaf)
  |> should.equal(Ok(leaf))

  // Branch with leaves
  let tree = Branch(Leaf(1), Leaf(2))
  let encoded_tree = codec.encode(c, tree)
  codec.decode(c, encoded_tree)
  |> should.equal(Ok(tree))

  // Nested branches
  let nested = Branch(Branch(Leaf(1), Leaf(2)), Leaf(3))
  let encoded_nested = codec.encode(c, nested)
  codec.decode(c, encoded_nested)
  |> should.equal(Ok(nested))
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
  |> should.equal(user)
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
  |> should.equal(users)
}
