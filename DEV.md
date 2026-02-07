# Development Guide

This document provides detailed instructions for developing and contributing to msgpack_gleam.

## Prerequisites

Ensure you have the following installed:

| Tool | Version | Purpose |
|------|---------|---------|
| Erlang/OTP | 27.2.1+ | BEAM runtime |
| Gleam | 1.14.0+ | Compiler and tooling |
| just | 1.38.0+ | Task runner |

**Recommended:** Use [mise](https://mise.jdx.dev/) or [asdf](https://asdf-vm.com/) with `.tool-versions`.

```bash
mise install
```

## Getting Started

```bash
# Clone the repository
git clone <repo-url>
cd msgpack_gleam

# Install dependencies
just deps

# Verify everything works
just ci
```

## Development Workflow

### Daily Development

```bash
# Type check
just check

# Run tests
just test

# Format code
just format
```

### Before Committing

```bash
# Run full CI checks
just pr
```

### Before Merging to Main

```bash
# Run extended checks including docs
just main
```

## Project Structure

```
.
├── src/
│   ├── msgpack_gleam.gleam        # Main public API
│   └── msgpack_gleam/
│       ├── value.gleam            # Value union type
│       ├── error.gleam            # Error types
│       ├── encode.gleam           # Binary encoding
│       ├── decode.gleam           # Binary decoding
│       ├── codec.gleam            # Bidirectional codecs
│       └── timestamp.gleam        # Timestamp extension
├── codegen/                       # Code generation subproject
│   ├── src/
│   │   ├── msgpack_codegen.gleam
│   │   └── msgpack_codegen/
│   │       └── generator.gleam
│   └── gleam.toml
├── test/
│   ├── msgpack_gleam_test.gleam
│   ├── codec_test.gleam
│   ├── test_helpers.gleam
│   └── test_data/
│       └── msgpack-test-suite.json
├── .github/
│   ├── actions/setup/             # Reusable CI setup
│   └── workflows/
├── gleam.toml
└── justfile
```

## Code Style

### Formatting

```bash
just format
```

### Binary Patterns

Use Gleam's bit syntax for encoding/decoding:

```gleam
// Encoding
<<0xc0>>  // nil
<<0xc2>>  // false
<<0xc3>>  // true

// Decoding with guards
<<n:8, rest:bits>> if n <= 0x7f -> Ok(#(Integer(n), rest))
```

### Error Handling

Use typed error types:

```gleam
pub type EncodeError {
  IntegerTooLarge(Int)
  StringTooLong(Int)
}

pub type DecodeError {
  UnexpectedEof
  InvalidFormat(Int)
}
```

## Testing

### Running Tests

```bash
# Run all tests
just test

# Run with verbose output
gleam test -- --verbose
```

### Test Suite

Tests use the official MessagePack test suite:

```gleam
import test_helpers

pub fn roundtrip_test() {
  let suite = test_helpers.load_test_suite("test/test_data/msgpack-test-suite.json")
  // ...
}
```

### Writing Tests

```gleam
import gleeunit/should
import msgpack_gleam

pub fn encode_nil_test() {
  msgpack_gleam.pack(msgpack_gleam.Nil)
  |> should.equal(Ok(<<0xc0>>))
}
```

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(codec): add float codec
fix(decode): handle trailing bytes correctly
perf(encode): optimize integer encoding
test: add edge case tests for timestamps
```

## Codegen Subproject

The `codegen/` directory contains a code generation tool:

```bash
cd codegen
gleam deps download
gleam run -- --help
```

This generates encoder/decoder code from type annotations.

## Troubleshooting

### Build Errors

```bash
just clean
just deps
just build
```

### Test Data Issues

Ensure the test suite JSON is present:

```bash
ls test/test_data/msgpack-test-suite.json
```
