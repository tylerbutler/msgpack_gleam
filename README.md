# msgpack_gleam

A [MessagePack](https://msgpack.org/) implementation for Gleam.

## Installation

```sh
gleam add msgpack_gleam
```

## Usage

```gleam
import msgpack_gleam

pub fn main() {
  // Encode a value to MessagePack binary format
  let encoded = msgpack_gleam.encode(msgpack_gleam.Int(42))

  // Decode MessagePack binary back to a value
  let decoded = msgpack_gleam.decode(encoded)
}
```

## Development

```sh
gleam build  # Build the project
gleam test   # Run the tests
gleam docs build  # Generate documentation
```
