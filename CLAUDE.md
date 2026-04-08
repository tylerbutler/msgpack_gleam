# msgpack_gleam

## Project Overview

A pure Gleam implementation of [MessagePack](https://msgpack.org/), an efficient binary serialization format. Supports all MessagePack types including extension types and timestamps. Targets the Erlang (BEAM) runtime.

## Build Commands

```bash
gleam build              # Compile project
gleam test               # Run tests
gleam check              # Type check without building
gleam format src test    # Format code
gleam docs build         # Generate documentation
```

## Just Commands

```bash
just deps             # Download dependencies
just build            # Build project
just build-strict     # Build with warnings as errors
just test             # Run tests
just format           # Format code
just format-check     # Check formatting
just check            # Type check
just docs             # Build documentation
just ci               # Run all CI checks (format, check, test, build-strict)
just pr               # Alias for ci (use before PR)
just main             # Extended checks for main branch (ci + docs)
just clean            # Remove build artifacts
just change           # Create a new changelog entry (changie new)
just changelog-preview # Preview unreleased changelog
just changelog        # Generate CHANGELOG.md (changie merge)
```

## Project Structure

```
src/
├── msgpack_gleam.gleam        # Main public API (pack/unpack/unpack_exact)
└── msgpack_gleam/
    ├── value.gleam            # Value union type (all MessagePack types)
    ├── error.gleam            # EncodeError and DecodeError types
    ├── encode.gleam           # Binary encoding (Value → BitArray)
    ├── decode.gleam           # Binary decoding (BitArray → Value)
    ├── codec.gleam            # Bidirectional codecs (Gleam types ↔ Value)
    └── timestamp.gleam        # Timestamp extension type (-1)
codegen/                       # Separate Gleam project for code generation
    ├── gleam.toml
    └── src/
test/
├── msgpack_gleam_test.gleam   # Core encode/decode/roundtrip tests
├── codec_test.gleam           # Codec combinator tests
├── test_helpers.gleam         # Test suite loader and hex parsing
└── test_data/
    └── msgpack-test-suite.json # Official msgpack test vectors
```

## Architecture

### Three-Layer Design

1. **Value layer** (`value.gleam`): A union type representing all MessagePack types — `Nil`, `Boolean`, `Integer`, `Float`, `String`, `Binary`, `Array`, `Map`, `Extension`.

2. **Binary layer** (`encode.gleam`, `decode.gleam`): Converts between `Value` and MessagePack wire format. Encoding always produces the smallest valid (canonical) representation. Decoding is streaming — `decode` returns `#(Value, BitArray)` with remaining bytes.

3. **Codec layer** (`codec.gleam`): Bidirectional codecs converting between Gleam types and `Value`. Combinators include: primitives (`int`, `string`, `float`, etc.), collections (`list`, `dict`, `string_dict`), objects (`object2`..`object8` with `field` descriptors), `nullable`, `lazy` (recursive types), `one_of`, `with_default`, `try_map`.

### Public API

`src/msgpack_gleam.gleam` exposes three functions:
- `pack(Value) -> Result(BitArray, EncodeError)` — encode to binary
- `unpack(BitArray) -> Result(#(Value, BitArray), DecodeError)` — decode with remaining bytes
- `unpack_exact(BitArray) -> Result(Value, DecodeError)` — decode, reject trailing bytes

### Error Types

Two separate error hierarchies:
- `error.gleam`: `EncodeError` and `DecodeError` for binary-level encoding/decoding errors
- `codec.gleam`: `DecodeError` for codec-level errors with field paths (`FieldError`, `MissingField`, `TypeMismatch`)

### Codegen Subproject

`codegen/` is a separate Gleam project with its own `gleam.toml` and dependencies. It generates encoder/decoder code from type annotations using `glance` for parsing.

## Dependencies

### Runtime
- `gleam_stdlib` - Standard library

### Development
- `startest` - Testing framework
- `gleam_json` - JSON parsing for test suite
- `simplifile` - File I/O for test suite loading

## Testing

```bash
just test
# or
gleam test
```

Tests validate against the official [msgpack-test-suite](https://github.com/kawanet/msgpack-test-suite) JSON at `test/test_data/msgpack-test-suite.json`. Test helpers in `test_helpers.gleam` parse hex-encoded test vectors.

## Tool Versions

Managed via `.tool-versions` (source of truth for CI):
- Erlang 27.2.1
- Gleam 1.14.0
- just 1.38.0

## CI/CD

### Workflows
- **ci.yml**: Format check, type check, build (warnings as errors), test
- **pr.yml**: PR title validation (commitlint), changelog entry check (changie)
- **release.yml**: Automated versioning via changie-release
- **auto-tag.yml**: Auto-tag on release PR merge
- **publish.yml**: Publish to Hex.pm on tag push

## Conventions

- Use Result types over exceptions
- Exhaustive pattern matching
- Follow `gleam format` output
- Document public functions with `///` comments
- Encoding always produces canonical (smallest valid) representation

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(codec): add float codec
fix(decode): handle trailing bytes correctly
perf(encode): optimize integer encoding
test: add edge case tests for timestamps
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

## Changelog

Uses [changie](https://changie.dev/) for fragment-based changelog management. Run `just change` to create a new entry. Fragments live in `.changes/unreleased/`.
