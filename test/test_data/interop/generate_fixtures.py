#!/usr/bin/env python3
"""
Generate cross-language interoperability test fixtures for msgpack_gleam.

Uses Python's msgpack library as the reference implementation to encode
representative values to binary .msgpack files, plus a manifest.json
describing expected decoded values.

Usage:
    python3 generate_fixtures.py

Generates files in the current directory.
"""

import json
import os
import struct
import msgpack


def hex_encode(data: bytes) -> str:
    return data.hex()


def write_fixture(name: str, data: bytes, outdir: str = ".") -> str:
    path = os.path.join(outdir, name)
    with open(path, "wb") as f:
        f.write(data)
    return hex_encode(data)


def generate_integer_boundaries() -> list[dict]:
    """Generate fixtures for all integer format boundary values."""
    cases = [
        # Negative fixint range: -32 to -1 (0xe0 to 0xff)
        ("int_neg1.msgpack", -1, "largest negative fixint"),
        ("int_neg32.msgpack", -32, "smallest negative fixint"),
        # int8 range: -128 to -33
        ("int_neg33.msgpack", -33, "smallest int8 (just below fixint)"),
        ("int_neg128.msgpack", -128, "int8 minimum"),
        # int16 range: -32768 to -129
        ("int_neg129.msgpack", -129, "smallest int16 (just below int8)"),
        ("int_neg32768.msgpack", -32768, "int16 minimum"),
        # int32 range: -2147483648 to -32769
        ("int_neg32769.msgpack", -32769, "smallest int32 (just below int16)"),
        ("int_neg2147483648.msgpack", -2147483648, "int32 minimum"),
        # int64 range
        ("int_neg2147483649.msgpack", -2147483649, "smallest int64 (just below int32)"),
        ("int_neg_min64.msgpack", -(2**63), "int64 minimum (-2^63)"),
        # Positive fixint range: 0 to 127 (0x00 to 0x7f)
        ("int_0.msgpack", 0, "zero (positive fixint)"),
        ("int_1.msgpack", 1, "one (positive fixint)"),
        ("int_127.msgpack", 127, "largest positive fixint"),
        # uint8 range: 128 to 255
        ("int_128.msgpack", 128, "smallest uint8 (just above fixint)"),
        ("int_255.msgpack", 255, "uint8 maximum"),
        # uint16 range: 256 to 65535
        ("int_256.msgpack", 256, "smallest uint16 (just above uint8)"),
        ("int_65535.msgpack", 65535, "uint16 maximum"),
        # uint32 range: 65536 to 4294967295
        ("int_65536.msgpack", 65536, "smallest uint32 (just above uint16)"),
        ("int_4294967295.msgpack", 4294967295, "uint32 maximum"),
        # uint64 range
        ("int_4294967296.msgpack", 4294967296, "smallest uint64 (just above uint32)"),
        ("int_max64.msgpack", 2**63 - 1, "int64 maximum (2^63-1)"),
    ]

    fixtures = []
    for filename, value, description in cases:
        data = msgpack.packb(value)
        hex_str = hex_encode(data)
        entry = {
            "file": filename,
            "description": description,
            "type": "integer",
            "msgpack_hex": hex_str,
        }
        # Use string for values outside JSON safe integer range
        if abs(value) > 2**53:
            entry["bignum"] = str(value)
        else:
            entry["number"] = value
        fixtures.append(entry)
    return fixtures


def generate_nested_structures() -> list[dict]:
    """Generate fixtures for deeply nested and complex structures."""
    cases = []

    # Map of arrays of maps (3 levels deep)
    nested1 = {
        "users": [
            {"name": "Alice", "scores": [95, 87, 92]},
            {"name": "Bob", "scores": [88, 91, 85]},
        ]
    }
    cases.append(("nested_map_array_map.msgpack", nested1,
                   "map containing arrays containing maps"))

    # 3D array (array of arrays of arrays)
    nested2 = [[[1, 2], [3, 4]], [[5, 6], [7, 8]]]
    cases.append(("nested_3d_array.msgpack", nested2, "3D array (3 levels deep)"))

    # Deeply nested maps (4 levels)
    nested3 = {"a": {"b": {"c": {"d": "deep"}}}}
    cases.append(("nested_deep_maps.msgpack", nested3,
                   "4-level nested maps"))

    # Empty nested structures
    nested4 = {"empty_array": [], "empty_map": {}, "nested_empty": {"inner": []}}
    cases.append(("nested_empty.msgpack", nested4,
                   "nested structures with empty collections"))

    fixtures = []
    for filename, value, description in cases:
        data = msgpack.packb(value, use_bin_type=True)
        hex_str = hex_encode(data)
        fixtures.append({
            "file": filename,
            "description": description,
            "type": "nested",
            "value": value,
            "msgpack_hex": hex_str,
        })
    return fixtures


def generate_large_data() -> list[dict]:
    """Generate fixtures for large strings and binary data."""
    cases = []

    # 200-byte string (requires str8 format: 32-255 bytes)
    str_200 = "A" * 200
    cases.append(("large_string_200.msgpack", str_200,
                   "200-byte string (str8 format)"))

    # 300-byte string (requires str16 format: 256-65535 bytes)
    str_300 = "B" * 300
    cases.append(("large_string_300.msgpack", str_300,
                   "300-byte string (str16 format)"))

    # 70000-byte string (requires str32 format: > 65535 bytes)
    str_70k = "C" * 70_000
    cases.append(("large_string_70k.msgpack", str_70k,
                   "70000-byte string (str32 format)"))

    fixtures = []
    for filename, value, description in cases:
        data = msgpack.packb(value, use_bin_type=True)
        hex_str = hex_encode(data)
        fixtures.append({
            "file": filename,
            "description": description,
            "type": "string",
            "string_length": len(value),
            "string_char": value[0],
            "msgpack_hex": hex_str,
        })

    # 200-byte binary (requires bin8 format: 0-255 bytes)
    bin_200 = bytes(range(200))
    data = msgpack.packb(bin_200, use_bin_type=True)
    fixtures.append({
        "file": "large_binary_200.msgpack",
        "description": "200-byte binary data (bin8 format)",
        "type": "binary",
        "binary_hex": hex_encode(bin_200),
        "binary_length": 200,
        "msgpack_hex": hex_encode(data),
    })

    # 500-byte binary (requires bin16 format: 256-65535 bytes)
    bin_500 = bytes(range(256)) + bytes(range(244))
    data = msgpack.packb(bin_500, use_bin_type=True)
    fixtures.append({
        "file": "large_binary_500.msgpack",
        "description": "500-byte binary data (bin16 format)",
        "type": "binary",
        "binary_hex": hex_encode(bin_500),
        "binary_length": 500,
        "msgpack_hex": hex_encode(data),
    })

    return fixtures


def generate_mixed_types() -> list[dict]:
    """Generate fixtures with mixed-type arrays and maps."""
    cases = []

    # Array with every type
    mixed_array = [None, True, False, 42, -1, 3.14, "hello", b"\xde\xad", [1, 2], {"a": 1}]
    data = msgpack.packb(mixed_array, use_bin_type=True)
    cases.append({
        "file": "mixed_array.msgpack",
        "description": "array containing nil, bool, int, float, string, binary, array, map",
        "type": "mixed_array",
        "value": {
            "items": [
                {"type": "nil"},
                {"type": "bool", "value": True},
                {"type": "bool", "value": False},
                {"type": "integer", "value": 42},
                {"type": "integer", "value": -1},
                {"type": "float", "value": 3.14},
                {"type": "string", "value": "hello"},
                {"type": "binary", "hex": "dead"},
                {"type": "array", "value": [1, 2]},
                {"type": "map", "value": {"a": 1}},
            ]
        },
        "msgpack_hex": hex_encode(data),
    })

    # Map with integer keys (not just string keys)
    int_key_map = {1: "one", 2: "two", 3: "three"}
    data = msgpack.packb(int_key_map, use_bin_type=True)
    cases.append({
        "file": "mixed_int_key_map.msgpack",
        "description": "map with integer keys",
        "type": "int_key_map",
        "value": [[1, "one"], [2, "two"], [3, "three"]],
        "msgpack_hex": hex_encode(data),
    })

    # Map with mixed key types
    mixed_key_map = msgpack.packb(
        [(True, "bool_key"), ("str", "string_key"), (42, "int_key")],
        use_bin_type=True,
    )
    # Pack as a fixmap manually: 3 entries
    # Actually, let's use the packer with a dict-like structure
    # Python dicts only support hashable keys, so we need to build manually
    buf = b"\x83"  # fixmap with 3 entries
    buf += msgpack.packb(True) + msgpack.packb("bool_key", use_bin_type=True)
    buf += msgpack.packb("str", use_bin_type=True) + msgpack.packb("string_key", use_bin_type=True)
    buf += msgpack.packb(42) + msgpack.packb("int_key", use_bin_type=True)
    cases.append({
        "file": "mixed_key_map.msgpack",
        "description": "map with mixed key types (bool, string, int)",
        "type": "mixed_key_map",
        "value": [
            [{"type": "bool", "value": True}, "bool_key"],
            [{"type": "string", "value": "str"}, "string_key"],
            [{"type": "integer", "value": 42}, "int_key"],
        ],
        "msgpack_hex": hex_encode(buf),
    })
    # Override data for this one since we built it manually
    cases[-1]["_data"] = buf

    return cases


def generate_timestamps() -> list[dict]:
    """Generate fixtures for MessagePack timestamp extension types."""
    cases = []

    # Timestamp32: seconds only, fits in 32 bits (type -1, 4 bytes data)
    # Format: fixext4 (0xd6), type=-1 (0xff), 4 bytes seconds big-endian
    ts32_seconds = 1234567890
    ts32_data = b"\xd6\xff" + struct.pack(">I", ts32_seconds)
    cases.append({
        "file": "timestamp32.msgpack",
        "description": "timestamp32 format (seconds only, 4 bytes)",
        "type": "timestamp",
        "timestamp": [ts32_seconds, 0],
        "msgpack_hex": hex_encode(ts32_data),
        "_data": ts32_data,
    })

    # Timestamp64: seconds + nanoseconds packed into 8 bytes
    # Upper 30 bits = nanoseconds adjustment, lower 34 bits = seconds
    # Format: fixext8 (0xd7), type=-1 (0xff), 8 bytes
    ts64_seconds = 1234567890
    ts64_nanos = 500000000
    ts64_val = (ts64_nanos << 34) | ts64_seconds
    ts64_data = b"\xd7\xff" + struct.pack(">Q", ts64_val)
    cases.append({
        "file": "timestamp64.msgpack",
        "description": "timestamp64 format (seconds + nanoseconds, 8 bytes)",
        "type": "timestamp",
        "timestamp": [ts64_seconds, ts64_nanos],
        "msgpack_hex": hex_encode(ts64_data),
        "_data": ts64_data,
    })

    # Timestamp96: large seconds, 12 bytes
    # Format: ext8 (0xc7), length=12, type=-1 (0xff), 4 bytes nanos, 8 bytes seconds (signed)
    ts96_seconds = 253402300799  # year 9999-12-31T23:59:59
    ts96_nanos = 999999999
    ts96_data = (
        b"\xc7\x0c\xff"
        + struct.pack(">I", ts96_nanos)
        + struct.pack(">q", ts96_seconds)
    )
    cases.append({
        "file": "timestamp96.msgpack",
        "description": "timestamp96 format (large seconds, 12 bytes)",
        "type": "timestamp",
        "timestamp": [ts96_seconds, ts96_nanos],
        "msgpack_hex": hex_encode(ts96_data),
        "_data": ts96_data,
    })

    # Timestamp with zero (epoch)
    ts_epoch_data = b"\xd6\xff" + struct.pack(">I", 0)
    cases.append({
        "file": "timestamp_epoch.msgpack",
        "description": "timestamp at Unix epoch (0 seconds)",
        "type": "timestamp",
        "timestamp": [0, 0],
        "msgpack_hex": hex_encode(ts_epoch_data),
        "_data": ts_epoch_data,
    })

    return cases


def generate_streaming() -> list[dict]:
    """Generate fixtures with multiple concatenated values for streaming decode."""
    cases = []

    # Three simple values concatenated
    stream1 = msgpack.packb(42) + msgpack.packb("hello", use_bin_type=True) + msgpack.packb(True)
    cases.append({
        "file": "stream_three_values.msgpack",
        "description": "3 concatenated values: int(42), string(hello), bool(true)",
        "type": "stream",
        "values": [
            {"type": "integer", "value": 42},
            {"type": "string", "value": "hello"},
            {"type": "bool", "value": True},
        ],
        "msgpack_hex": hex_encode(stream1),
        "_data": stream1,
    })

    # Five mixed values
    stream2 = (
        msgpack.packb(None)
        + msgpack.packb(255)
        + msgpack.packb("test", use_bin_type=True)
        + msgpack.packb([1, 2, 3])
        + msgpack.packb({"key": "val"}, use_bin_type=True)
    )
    cases.append({
        "file": "stream_five_values.msgpack",
        "description": "5 concatenated values: nil, int(255), string(test), array, map",
        "type": "stream",
        "values": [
            {"type": "nil"},
            {"type": "integer", "value": 255},
            {"type": "string", "value": "test"},
            {"type": "array", "value": [1, 2, 3]},
            {"type": "map", "value": {"key": "val"}},
        ],
        "msgpack_hex": hex_encode(stream2),
        "_data": stream2,
    })

    return cases


def main():
    outdir = os.path.dirname(os.path.abspath(__file__))

    all_fixtures = {}

    # Generate each category
    categories = [
        ("integer-boundaries", generate_integer_boundaries()),
        ("nested-structures", generate_nested_structures()),
        ("large-data", generate_large_data()),
        ("mixed-types", generate_mixed_types()),
        ("timestamps", generate_timestamps()),
        ("streaming", generate_streaming()),
    ]

    for category_name, fixtures in categories:
        for fixture in fixtures:
            filename = fixture["file"]
            # Use pre-built data if available, otherwise decode hex
            if "_data" in fixture:
                data = fixture.pop("_data")
            else:
                data = bytes.fromhex(fixture["msgpack_hex"])
            write_fixture(filename, data, outdir)

        all_fixtures[category_name] = fixtures

    # Write manifest
    manifest = {
        "generator": "python-msgpack",
        "generator_version": ".".join(str(x) for x in msgpack.version),
        "description": "Cross-language interoperability test fixtures for msgpack_gleam",
        "fixtures": all_fixtures,
    }

    manifest_path = os.path.join(outdir, "manifest.json")
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    # Print summary
    total = sum(len(v) for v in all_fixtures.values())
    print(f"Generated {total} fixtures in {outdir}")
    for cat, fixtures in all_fixtures.items():
        print(f"  {cat}: {len(fixtures)} fixtures")


if __name__ == "__main__":
    main()
