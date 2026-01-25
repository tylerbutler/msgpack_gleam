import gleeunit
import gleeunit/should
import msgpack_codegen/generator

pub fn main() {
  gleeunit.main()
}

const simple_record_source = "
/// @derive(msgpack)
pub type User {
  User(id: Int, name: String, email: Option(String))
}
"

const variant_source = "
/// @derive(msgpack)
pub type Status {
  Active
  Inactive
  Pending(reason: String)
}
"

const nested_types_source = "
/// @derive(msgpack)
pub type Order {
  Order(
    id: Int,
    items: List(String),
    metadata: Dict(String, String),
  )
}
"

const no_derive_source = "
pub type Internal {
  Internal(value: Int)
}
"

pub fn parse_simple_record_test() {
  let assert Ok(result) = generator.parse_source(simple_record_source)

  result.types_to_generate
  |> should.not_equal([])

  case result.types_to_generate {
    [generator.RecordType(name, params, fields, is_public)] -> {
      name
      |> should.equal("User")

      params
      |> should.equal([])

      is_public
      |> should.be_true()

      case fields {
        [f1, f2, f3] -> {
          f1.name
          |> should.equal("id")
          f1.gleam_type
          |> should.equal("Int")
          f1.is_optional
          |> should.be_false()

          f2.name
          |> should.equal("name")
          f2.gleam_type
          |> should.equal("String")

          f3.name
          |> should.equal("email")
          f3.is_optional
          |> should.be_true()
        }
        _ -> should.fail()
      }
    }
    _ -> should.fail()
  }
}

pub fn parse_variant_type_test() {
  let assert Ok(result) = generator.parse_source(variant_source)

  result.types_to_generate
  |> should.not_equal([])

  case result.types_to_generate {
    [generator.VariantType(name, _, variants, _)] -> {
      name
      |> should.equal("Status")

      case variants {
        [v1, v2, v3] -> {
          v1.name
          |> should.equal("Active")
          v1.fields
          |> should.equal([])

          v2.name
          |> should.equal("Inactive")

          v3.name
          |> should.equal("Pending")
          case v3.fields {
            [f] -> {
              f.name
              |> should.equal("reason")
              f.gleam_type
              |> should.equal("String")
            }
            _ -> should.fail()
          }
        }
        _ -> should.fail()
      }
    }
    _ -> should.fail()
  }
}

pub fn skip_unmarked_types_test() {
  let assert Ok(result) = generator.parse_source(no_derive_source)

  result.types_to_generate
  |> should.equal([])
}

pub fn generate_record_codec_test() {
  let assert Ok(result) = generator.parse_source(simple_record_source)
  let assert Ok(generated) =
    generator.generate_codecs(result, generator.default_config())

  // Check that generated code contains expected elements
  should.be_true(contains(generated, "fn user_codec()"))
  should.be_true(contains(generated, "Codec(User)"))
  should.be_true(contains(generated, "codec.object3"))
  should.be_true(contains(generated, "codec.field(\"id\""))
  should.be_true(contains(generated, "codec.field(\"name\""))
  should.be_true(contains(generated, "codec.field(\"email\""))
  should.be_true(contains(generated, "codec.nullable(codec.string())"))
}

pub fn generate_variant_codec_test() {
  let assert Ok(result) = generator.parse_source(variant_source)
  let assert Ok(generated) =
    generator.generate_codecs(result, generator.default_config())

  // Check that generated code contains expected elements
  should.be_true(contains(generated, "fn status_codec()"))
  should.be_true(contains(generated, "codec.custom"))
  should.be_true(contains(generated, "\"active\""))
  should.be_true(contains(generated, "\"inactive\""))
  should.be_true(contains(generated, "\"pending\""))
}

pub fn generate_nested_types_codec_test() {
  let assert Ok(result) = generator.parse_source(nested_types_source)
  let assert Ok(generated) =
    generator.generate_codecs(result, generator.default_config())

  // Check for list and dict codec usage
  should.be_true(contains(generated, "codec.list(codec.string())"))
  should.be_true(contains(generated, "codec.string_dict(codec.string())"))
}

fn contains(haystack: String, needle: String) -> Bool {
  case haystack {
    "" -> needle == ""
    _ -> {
      case string_starts_with(haystack, needle) {
        True -> True
        False -> contains(string_drop_first(haystack), needle)
      }
    }
  }
}

@external(erlang, "string", "prefix")
fn string_prefix(s: String, prefix: String) -> a

fn string_starts_with(s: String, prefix: String) -> Bool {
  case string_prefix(s, prefix) {
    _ if s == "" -> prefix == ""
    result -> result != s
  }
}

@external(erlang, "string", "slice")
fn string_drop_first(s: String) -> String
