/// Code generator for msgpack_gleam codecs.
///
/// Parses Gleam source files and generates codec definitions for types
/// marked with `/// @derive(msgpack)` comments.
import glance.{
  type CustomType, type Definition, type Module, type Type, type Variant,
  type VariantField, LabelledVariantField, NamedType, TupleType,
  UnlabelledVariantField, Variant,
}
import gleam/int
import gleam/list
import gleam/string

/// Configuration for code generation
pub type Config {
  Config(
    /// Module name for the generated codecs
    output_module: String,
    /// Whether to generate public or private codecs
    public_codecs: Bool,
    /// Custom field name mapping (gleam_name -> wire_name)
    field_mappings: List(#(String, String)),
  )
}

/// Default configuration
pub fn default_config() -> Config {
  Config(output_module: "codecs", public_codecs: True, field_mappings: [])
}

/// Result of parsing a source file
pub type ParseResult {
  ParseResult(
    /// Types marked for codec generation
    types_to_generate: List(TypeInfo),
    /// Any errors encountered
    errors: List(String),
  )
}

/// Information about a type to generate a codec for
pub type TypeInfo {
  RecordType(
    name: String,
    type_params: List(String),
    fields: List(FieldInfo),
    is_public: Bool,
  )
  VariantType(
    name: String,
    type_params: List(String),
    variants: List(VariantInfo),
    is_public: Bool,
  )
}

/// Information about a record field
pub type FieldInfo {
  FieldInfo(name: String, gleam_type: String, is_optional: Bool)
}

/// Information about a variant
pub type VariantInfo {
  VariantInfo(name: String, fields: List(FieldInfo))
}

/// Parse a Gleam source file and extract types marked for codec generation
pub fn parse_source(source: String) -> Result(ParseResult, String) {
  case glance.module(source) {
    Ok(module) -> Ok(extract_marked_types(module, source))
    Error(err) -> Error("Failed to parse source: " <> string.inspect(err))
  }
}

/// Extract types marked with @derive(msgpack)
fn extract_marked_types(module: Module, source: String) -> ParseResult {
  let types_and_errors =
    module.custom_types
    |> list.filter_map(fn(def: Definition(CustomType)) {
      let custom_type = def.definition
      // Check if the type has a @derive(msgpack) comment
      case should_derive_codec(custom_type, source) {
        True -> Ok(convert_custom_type(custom_type))
        False -> Error(Nil)
      }
    })

  ParseResult(types_to_generate: types_and_errors, errors: [])
}

/// Check if a type should have a codec generated
fn should_derive_codec(custom_type: CustomType, source: String) -> Bool {
  // Look for @derive(msgpack) in the doc comment immediately before this type
  let type_name = custom_type.name
  let derive_pattern = "@derive(msgpack)"

  // Find the type definition in source and check for derive annotation
  case string.split(source, "pub type " <> type_name) {
    [before, ..] -> {
      // Get the doc comment block that immediately precedes the type
      let doc_comment = extract_preceding_doc_comment(before)
      string.contains(doc_comment, derive_pattern)
    }
    _ ->
      case string.split(source, "type " <> type_name) {
        [before, ..] -> {
          let doc_comment = extract_preceding_doc_comment(before)
          string.contains(doc_comment, derive_pattern)
        }
        _ -> False
      }
  }
}

/// Extract the doc comment block immediately before a type definition
fn extract_preceding_doc_comment(before: String) -> String {
  // Split into lines and take lines from the end that are doc comments
  before
  |> string.split("\n")
  |> list.reverse()
  |> take_doc_comment_lines([])
  |> string.join("\n")
}

/// Take consecutive doc comment lines from the reversed list
fn take_doc_comment_lines(
  lines: List(String),
  acc: List(String),
) -> List(String) {
  case lines {
    [] -> acc
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "///") {
        True -> take_doc_comment_lines(rest, [line, ..acc])
        False ->
          case trimmed {
            // Skip empty lines between doc comment and type
            "" -> take_doc_comment_lines(rest, acc)
            // Stop at any non-doc-comment, non-empty line
            _ -> acc
          }
      }
    }
  }
}

/// Convert a glance CustomType to our TypeInfo
fn convert_custom_type(custom_type: CustomType) -> TypeInfo {
  let type_params = custom_type.parameters
  let is_public = custom_type.publicity == glance.Public

  case custom_type.variants {
    // Single variant with same name as type = record type
    [Variant(name, fields, _attributes)] if name == custom_type.name ->
      RecordType(
        name: custom_type.name,
        type_params: type_params,
        fields: list.map(fields, convert_variant_field),
        is_public: is_public,
      )
    // Multiple variants or different name = variant/enum type
    variants ->
      VariantType(
        name: custom_type.name,
        type_params: type_params,
        variants: list.map(variants, convert_variant),
        is_public: is_public,
      )
  }
}

/// Convert a glance Variant to our VariantInfo
fn convert_variant(variant: Variant) -> VariantInfo {
  VariantInfo(
    name: variant.name,
    fields: list.map(variant.fields, convert_variant_field),
  )
}

/// Convert a glance VariantField to our FieldInfo
fn convert_variant_field(field: VariantField) -> FieldInfo {
  case field {
    LabelledVariantField(item: t, label: label) -> {
      let #(gleam_type, is_optional) = convert_type(t)
      FieldInfo(name: label, gleam_type: gleam_type, is_optional: is_optional)
    }
    UnlabelledVariantField(item: t) -> {
      let #(gleam_type, is_optional) = convert_type(t)
      FieldInfo(name: "_", gleam_type: gleam_type, is_optional: is_optional)
    }
  }
}

/// Convert a glance Type to a string representation
fn convert_type(t: Type) -> #(String, Bool) {
  case t {
    NamedType(_location, name, _module, params) -> {
      case name, params {
        // Option type
        "Option", [inner] -> {
          let #(inner_type, _) = convert_type(inner)
          #(inner_type, True)
        }
        // List type
        "List", [inner] -> {
          let #(inner_type, _) = convert_type(inner)
          #("List(" <> inner_type <> ")", False)
        }
        // Dict type
        "Dict", [key, val] -> {
          let #(key_type, _) = convert_type(key)
          let #(val_type, _) = convert_type(val)
          #("Dict(" <> key_type <> ", " <> val_type <> ")", False)
        }
        // Simple types
        _, [] -> #(name, False)
        // Generic types
        _, type_args -> {
          let args_str =
            type_args
            |> list.map(fn(a) { convert_type(a).0 })
            |> string.join(", ")
          #(name <> "(" <> args_str <> ")", False)
        }
      }
    }
    TupleType(_location, elements) -> {
      let elements_str =
        elements
        |> list.map(fn(e) { convert_type(e).0 })
        |> string.join(", ")
      #("#(" <> elements_str <> ")", False)
    }
    _ -> #("Dynamic", False)
  }
}

/// Generate codec code for the parsed types
pub fn generate_codecs(
  parse_result: ParseResult,
  config: Config,
) -> Result(String, String) {
  let type_infos = parse_result.types_to_generate

  case type_infos {
    [] -> Error("No types marked with @derive(msgpack) found")
    _ -> {
      let imports = generate_imports(type_infos)
      let codecs =
        type_infos
        |> list.map(fn(t) { generate_codec_for_type(t, config) })
        |> string.join("\n\n")

      Ok(imports <> "\n\n" <> codecs)
    }
  }
}

/// Generate import statements
fn generate_imports(_types: List(TypeInfo)) -> String {
  "import gleam/option.{type Option, None, Some}
import gleam/result
import msgpack_gleam/codec.{type Codec}
import msgpack_gleam/value"
}

/// Generate codec for a single type
fn generate_codec_for_type(type_info: TypeInfo, config: Config) -> String {
  case type_info {
    RecordType(name, _params, fields, _is_public) ->
      generate_record_codec(name, fields, config)
    VariantType(name, _params, variants, _is_public) ->
      generate_variant_codec(name, variants, config)
  }
}

/// Generate codec for a record type
fn generate_record_codec(
  name: String,
  fields: List(FieldInfo),
  config: Config,
) -> String {
  let field_count = list.length(fields)
  let pub_modifier = case config.public_codecs {
    True -> "pub "
    False -> ""
  }
  let fn_name = to_snake_case(name) <> "_codec"

  let field_definitions =
    fields
    |> list.map(fn(f) { generate_field_definition(f, name) })
    |> string.join(",\n    ")

  "/// Codec for " <> name <> " records
" <> pub_modifier <> "fn " <> fn_name <> "() -> Codec(" <> name <> ") {
  codec.object" <> int.to_string(field_count) <> "(
    " <> name <> ",
    " <> field_definitions <> ",
  )
}"
}

/// Generate a field definition
fn generate_field_definition(field: FieldInfo, type_name: String) -> String {
  let codec_expr = type_to_codec(field.gleam_type, field.is_optional)
  let wire_name = to_snake_case(field.name)

  "codec.field(\""
  <> wire_name
  <> "\", "
  <> codec_expr
  <> ", fn(r: "
  <> type_name
  <> ") { r."
  <> field.name
  <> " })"
}

/// Convert a type string to a codec expression
fn type_to_codec(gleam_type: String, is_optional: Bool) -> String {
  let base_codec = type_to_codec_inner(gleam_type)

  case is_optional {
    True -> "codec.nullable(" <> base_codec <> ")"
    False -> base_codec
  }
}

fn type_to_codec_inner(gleam_type: String) -> String {
  case gleam_type {
    "String" -> "codec.string()"
    "Int" -> "codec.int()"
    "Float" -> "codec.float()"
    "Bool" -> "codec.bool()"
    "BitArray" -> "codec.binary()"
    other -> type_to_codec_complex(other)
  }
}

fn type_to_codec_complex(gleam_type: String) -> String {
  // Check for List(...)
  case string.starts_with(gleam_type, "List(") {
    True -> {
      let inner =
        gleam_type
        |> string.drop_start(5)
        |> string.drop_end(1)
      "codec.list(" <> type_to_codec_inner(inner) <> ")"
    }
    False -> type_to_codec_dict_or_tuple(gleam_type)
  }
}

fn type_to_codec_dict_or_tuple(gleam_type: String) -> String {
  // Check for Dict(String, ...)
  case string.starts_with(gleam_type, "Dict(String, ") {
    True -> {
      let inner =
        gleam_type
        |> string.drop_start(13)
        |> string.drop_end(1)
      "codec.string_dict(" <> type_to_codec_inner(inner) <> ")"
    }
    False -> type_to_codec_tuple_or_custom(gleam_type)
  }
}

fn type_to_codec_tuple_or_custom(gleam_type: String) -> String {
  // Check for #(...)
  case string.starts_with(gleam_type, "#(") {
    True -> {
      let inner =
        gleam_type
        |> string.drop_start(2)
        |> string.drop_end(1)
      let elements = string.split(inner, ", ")
      let tuple_size = list.length(elements)
      let element_codecs =
        elements
        |> list.map(type_to_codec_inner)
        |> string.join(", ")
      "codec.tuple" <> int.to_string(tuple_size) <> "(" <> element_codecs <> ")"
    }
    False -> {
      // Custom type - assume there's a codec function for it
      to_snake_case(gleam_type) <> "_codec()"
    }
  }
}

/// Generate codec for a variant type (tagged union)
fn generate_variant_codec(
  name: String,
  variants: List(VariantInfo),
  config: Config,
) -> String {
  let pub_modifier = case config.public_codecs {
    True -> "pub "
    False -> ""
  }
  let fn_name = to_snake_case(name) <> "_codec"

  let encoder_cases =
    variants
    |> list.map(generate_variant_encoder_case)
    |> string.join("\n        ")

  let decoder_cases =
    variants
    |> list.map(generate_variant_decoder_case)
    |> string.join("\n            ")

  "/// Codec for " <> name <> " variants
" <> pub_modifier <> "fn " <> fn_name <> "() -> Codec(" <> name <> ") {
  codec.custom(
    // Encoder
    fn(v) {
      case v {
        " <> encoder_cases <> "
      }
    },
    // Decoder
    fn(val) {
      case val {
        value.Map(pairs) -> {
          case find_type_tag(pairs) {
            " <> decoder_cases <> "
            Ok(other) -> Error(codec.CustomError(\"Unknown variant: \" <> other))
            Error(e) -> Error(e)
          }
        }
        _ -> Error(codec.TypeMismatch(\"Map\", \"other\"))
      }
    },
  )
}

fn find_type_tag(pairs: List(#(value.Value, value.Value))) -> Result(String, codec.DecodeError) {
  case pairs {
    [] -> Error(codec.MissingField(\"type\"))
    [#(value.String(\"type\"), value.String(tag)), ..] -> Ok(tag)
    [_, ..rest] -> find_type_tag(rest)
  }
}

fn decode_field(
  pairs: List(#(value.Value, value.Value)),
  name: String,
  field_codec: Codec(a),
) -> Result(a, codec.DecodeError) {
  case find_field(pairs, name) {
    Ok(val) -> codec.decode(field_codec, val)
    Error(e) -> Error(e)
  }
}

fn find_field(
  pairs: List(#(value.Value, value.Value)),
  name: String,
) -> Result(value.Value, codec.DecodeError) {
  case pairs {
    [] -> Error(codec.MissingField(name))
    [#(value.String(key), val), ..rest] ->
      case key == name {
        True -> Ok(val)
        False -> find_field(rest, name)
      }
    [_, ..rest] -> find_field(rest, name)
  }
}"
}

/// Generate encoder case for a variant
fn generate_variant_encoder_case(variant: VariantInfo) -> String {
  let tag = to_snake_case(variant.name)

  case variant.fields {
    [] ->
      variant.name
      <> " -> value.Map([#(value.String(\"type\"), value.String(\""
      <> tag
      <> "\"))])"
    fields -> {
      // Generate field bindings
      let bindings =
        fields
        |> list.index_map(fn(f, i) {
          case f.name {
            "_" -> "f" <> int.to_string(i)
            n -> n
          }
        })
        |> string.join(", ")

      // Generate field encodings
      let field_encodings =
        fields
        |> list.index_map(fn(f, i) {
          let var_name = case f.name {
            "_" -> "f" <> int.to_string(i)
            n -> n
          }
          let codec_expr = type_to_codec(f.gleam_type, f.is_optional)
          let wire_name = case f.name {
            "_" -> "field" <> int.to_string(i)
            n -> to_snake_case(n)
          }
          "#(value.String(\""
          <> wire_name
          <> "\"), codec.encode("
          <> codec_expr
          <> ", "
          <> var_name
          <> "))"
        })
        |> string.join(", ")

      variant.name
      <> "("
      <> bindings
      <> ") -> value.Map([#(value.String(\"type\"), value.String(\""
      <> tag
      <> "\")), "
      <> field_encodings
      <> "])"
    }
  }
}

/// Generate decoder case for a variant
fn generate_variant_decoder_case(variant: VariantInfo) -> String {
  let tag = to_snake_case(variant.name)

  case variant.fields {
    [] -> "Ok(\"" <> tag <> "\") -> Ok(" <> variant.name <> ")"
    fields -> {
      let field_decodings =
        fields
        |> list.index_map(fn(f, i) {
          let var_name = case f.name {
            "_" -> "f" <> int.to_string(i)
            n -> n
          }
          let wire_name = case f.name {
            "_" -> "field" <> int.to_string(i)
            n -> to_snake_case(n)
          }
          let codec_expr = type_to_codec(f.gleam_type, f.is_optional)
          "use "
          <> var_name
          <> " <- result.try(decode_field(pairs, \""
          <> wire_name
          <> "\", "
          <> codec_expr
          <> "))"
        })
        |> string.join("\n                  ")

      let constructor_args =
        fields
        |> list.index_map(fn(f, i) {
          case f.name {
            "_" -> "f" <> int.to_string(i)
            n -> n <> ":"
          }
        })
        |> string.join(", ")

      "Ok(\""
      <> tag
      <> "\") -> {\n                  "
      <> field_decodings
      <> "\n                  Ok("
      <> variant.name
      <> "("
      <> constructor_args
      <> "))\n                }"
    }
  }
}

/// Convert PascalCase to snake_case
fn to_snake_case(s: String) -> String {
  s
  |> string.to_graphemes()
  |> list.index_map(fn(char, i) {
    case is_uppercase(char), i {
      True, 0 -> string.lowercase(char)
      True, _ -> "_" <> string.lowercase(char)
      False, _ -> char
    }
  })
  |> string.join("")
}

fn is_uppercase(s: String) -> Bool {
  let lower = string.lowercase(s)
  lower != s && lower != ""
}
