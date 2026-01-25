# msgpack_gleam

A pure Gleam implementation of [MessagePack](https://msgpack.org/), an efficient binary serialization format.

## Features

- **Complete MessagePack specification support** - All data types including nil, bool, int, float, string, binary, array, map, and extension types
- **Canonical encoding** - Always produces the smallest valid encoding
- **Built-in timestamp support** - Convenience API for MessagePack timestamp extension type
- **Streaming decode** - Decode values from a byte stream with remaining bytes returned
- **Comprehensive test suite** - Validated against [msgpack-test-suite](https://github.com/kawanet/msgpack-test-suite)

## Installation

```sh
gleam add msgpack_gleam
```

## Quick Start

```gleam
import msgpack_gleam.{pack, unpack_exact}
import msgpack_gleam/value.{Integer, String, Array, Map}

pub fn main() {
  // Encode a value
  let assert Ok(data) = pack(Array([String("hello"), Integer(42)]))

  // Decode it back
  let assert Ok(value) = unpack_exact(data)
  // value == Array([String("hello"), Integer(42)])
}
```

## Value Types

MessagePack values are represented using the `Value` type from `msgpack_gleam/value`:

```gleam
import msgpack_gleam/value.{
  Nil, Boolean, Integer, Float, String, Binary, Array, Map, Extension
}

// Create values
let nil_val = Nil
let bool_val = Boolean(True)
let int_val = Integer(42)
let float_val = Float(3.14)
let str_val = String("hello")
let bin_val = Binary(<<1, 2, 3>>)
let arr_val = Array([Integer(1), Integer(2)])
let map_val = Map([#(String("key"), String("value"))])
let ext_val = Extension(1, <<0xaa, 0xbb>>)
```

## Timestamps

MessagePack has a built-in timestamp extension type (type -1). Use the `msgpack_gleam/timestamp` module:

```gleam
import msgpack_gleam.{pack, unpack_exact}
import msgpack_gleam/timestamp.{Timestamp}

// Create a timestamp
let ts = timestamp.from_unix_seconds(1_234_567_890)
// Or with nanoseconds: Timestamp(seconds: 1234567890, nanoseconds: 500_000_000)

// Encode it
let value = timestamp.encode(ts)
let assert Ok(data) = pack(value)

// Decode it back
let assert Ok(decoded_value) = unpack_exact(data)
let assert Ok(decoded_ts) = timestamp.decode(decoded_value)

// Convenience functions
let millis = timestamp.to_unix_millis(ts)
let from_millis = timestamp.from_unix_millis(1_234_567_890_123)
```

## Streaming Decode

When decoding from a stream of MessagePack values, use `unpack` which returns remaining bytes:

```gleam
import msgpack_gleam.{unpack}
import msgpack_gleam/value.{Integer}

// Decode from a stream with multiple values
let stream = <<0x01, 0x02, 0x03>>  // Three fixints: 1, 2, 3

let assert Ok(#(Integer(1), rest1)) = unpack(stream)
let assert Ok(#(Integer(2), rest2)) = unpack(rest1)
let assert Ok(#(Integer(3), <<>>)) = unpack(rest2)
```

## Error Handling

Encoding and decoding operations return `Result` types:

```gleam
import msgpack_gleam.{pack, unpack_exact}
import msgpack_gleam/error

// Encoding errors
case pack(value) {
  Ok(data) -> // use data
  Error(error.IntegerTooLarge(n)) -> // integer out of range
  Error(error.StringTooLong(len)) -> // string exceeds max length
  // etc.
}

// Decoding errors
case unpack_exact(data) {
  Ok(value) -> // use value
  Error(error.UnexpectedEof) -> // incomplete data
  Error(error.InvalidFormat(byte)) -> // invalid format byte
  Error(error.InvalidUtf8) -> // string is not valid UTF-8
  Error(error.TrailingBytes(n)) -> // extra bytes after value
  // etc.
}
```

## Development

```sh
just build   # Build the project
just test    # Run the tests
just docs    # Generate documentation
just         # List all available commands
```

## License

MIT
