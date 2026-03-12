# Copilot Instructions

## Build & Test

This is a Gleam project targeting the Erlang (BEAM) runtime. Use `just` as the task runner.

```sh
just build          # gleam build
just build-strict   # gleam build --warnings-as-errors
just test           # gleam test (startest runner)
just format         # gleam format src test
just format-check   # gleam format --check src test
just check          # gleam check (type checking)
just ci             # format-check + check + test + build-strict (alias: just pr)
just main           # ci + docs
just clean          # rm -rf build
just change         # changie new (create changelog entry)
```

Run a single test by filtering with startest:

```sh
gleam test -- --verbose           # all tests, verbose output
```

Gleam does not natively support running a single test. All tests are in `test/` and use the `startest` framework with `expect` assertions.

## Architecture

**msgpack_gleam** is a pure Gleam MessagePack library with three layers:

1. **Value layer** (`src/msgpack_gleam/value.gleam`) — A union type (`Value`) representing all MessagePack types: `Nil`, `Boolean`, `Integer`, `Float`, `String`, `Binary`, `Array`, `Map`, `Extension`.

2. **Binary encoding/decoding** (`encode.gleam`, `decode.gleam`) — Converts between `Value` and MessagePack binary format. Encoding always produces the smallest valid (canonical) representation. Decoding is streaming: `decode` returns remaining bytes, `decode_exact` rejects trailing bytes.

3. **Codec layer** (`codec.gleam`) — Bidirectional codecs that convert between Gleam types and `Value`. Provides combinators for primitives, collections, objects (up to `object8`), tuples, nullable, recursive types (`lazy`), and error-handling (`one_of`, `with_default`, `try_map`).

The public API (`src/msgpack_gleam.gleam`) exposes `pack`/`unpack`/`unpack_exact` which compose encode/decode internally.

**Codegen subproject** (`codegen/`) is a separate Gleam project that generates encoder/decoder code from type annotations. It has its own `gleam.toml` and dependencies.

## Key Conventions

- **Commit messages**: Conventional Commits enforced by commitlint. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Subject must be lowercase, no period, max 72 chars. Example: `feat(codec): add float codec`
- **Changelog**: Uses [changie](https://changie.dev/) for fragment-based changelog management. Run `just change` (or `changie new`) to create a changelog entry. Fragments live in `.changes/unreleased/`.
- **Release**: Automated via `tylerbutler/actions/changie-release`; version lives in `gleam.toml`
- **Testing**: Tests use the official [msgpack-test-suite](https://github.com/kawanet/msgpack-test-suite) JSON at `test/test_data/msgpack-test-suite.json`. Test helpers in `test/test_helpers.gleam` parse hex-encoded test vectors.
- **Error types**: Separate `EncodeError` and `DecodeError` types in `error.gleam` for binary-level errors. The codec layer has its own `DecodeError` type in `codec.gleam` with field paths.
- **Codec pattern**: Build codecs for custom types using `object2`..`object8` with `field()` descriptors. Use `codec.lazy` for recursive types.
- **Tooling**: Use `mise install` or `asdf install` to set up Erlang 27.2.1+, Gleam 1.14.0+, and just 1.38.0+ (see `.tool-versions`).
