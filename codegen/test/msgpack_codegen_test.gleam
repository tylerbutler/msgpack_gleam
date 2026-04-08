import gleam/string
import msgpack_codegen/generator
import startest
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
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
  |> expect.to_not_equal([])

  case result.types_to_generate {
    [generator.RecordType(name, params, fields, is_public)] -> {
      name
      |> expect.to_equal("User")

      params
      |> expect.to_equal([])

      is_public
      |> expect.to_be_true()

      case fields {
        [f1, f2, f3] -> {
          f1.name
          |> expect.to_equal("id")
          f1.gleam_type
          |> expect.to_equal("Int")
          f1.is_optional
          |> expect.to_be_false()

          f2.name
          |> expect.to_equal("name")
          f2.gleam_type
          |> expect.to_equal("String")

          f3.name
          |> expect.to_equal("email")
          f3.is_optional
          |> expect.to_be_true()
        }
        _ -> panic as "unreachable"
      }
    }
    _ -> panic as "unreachable"
  }
}

pub fn parse_variant_type_test() {
  let assert Ok(result) = generator.parse_source(variant_source)

  result.types_to_generate
  |> expect.to_not_equal([])

  case result.types_to_generate {
    [generator.VariantType(name, _, variants, _)] -> {
      name
      |> expect.to_equal("Status")

      case variants {
        [v1, v2, v3] -> {
          v1.name
          |> expect.to_equal("Active")
          v1.fields
          |> expect.to_equal([])

          v2.name
          |> expect.to_equal("Inactive")

          v3.name
          |> expect.to_equal("Pending")
          case v3.fields {
            [f] -> {
              f.name
              |> expect.to_equal("reason")
              f.gleam_type
              |> expect.to_equal("String")
            }
            _ -> panic as "unreachable"
          }
        }
        _ -> panic as "unreachable"
      }
    }
    _ -> panic as "unreachable"
  }
}

pub fn skip_unmarked_types_test() {
  let assert Ok(result) = generator.parse_source(no_derive_source)

  result.types_to_generate
  |> expect.to_equal([])
}

pub fn generate_record_codec_test() {
  let assert Ok(result) = generator.parse_source(simple_record_source)
  let assert Ok(generated) =
    generator.generate_codecs(result, generator.default_config())

  // Check that generated code contains expected elements
  expect.to_be_true(string.contains(generated, "fn user_codec()"))
  expect.to_be_true(string.contains(generated, "Codec(User)"))
  expect.to_be_true(string.contains(generated, "codec.object3"))
  expect.to_be_true(string.contains(generated, "codec.field(\"id\""))
  expect.to_be_true(string.contains(generated, "codec.field(\"name\""))
  expect.to_be_true(string.contains(generated, "codec.field(\"email\""))
  expect.to_be_true(string.contains(generated, "codec.nullable(codec.string())"))

}

pub fn generate_variant_codec_test() {
  let assert Ok(result) = generator.parse_source(variant_source)
  let assert Ok(generated) =
    generator.generate_codecs(result, generator.default_config())

  // Check that generated code contains expected elements
  expect.to_be_true(string.contains(generated, "fn status_codec()"))
  expect.to_be_true(string.contains(generated, "codec.custom"))
  expect.to_be_true(string.contains(generated, "\"active\""))
  expect.to_be_true(string.contains(generated, "\"inactive\""))
  expect.to_be_true(string.contains(generated, "\"pending\""))

}

pub fn generate_nested_types_codec_test() {
  let assert Ok(result) = generator.parse_source(nested_types_source)
  let assert Ok(generated) =
    generator.generate_codecs(result, generator.default_config())

  // Check for list and dict codec usage
  expect.to_be_true(string.contains(generated, "codec.list(codec.string())"))
  expect.to_be_true(string.contains(generated, "codec.string_dict(codec.string())"))
}
