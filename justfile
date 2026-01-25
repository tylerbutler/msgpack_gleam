# msgpack_gleam - MessagePack implementation for Gleam

# === ALIASES ===
alias b := build
alias t := test
alias f := format
alias l := lint
alias c := clean

default:
    @just --list

# === STANDARD RECIPES ===

build:
    gleam build

test:
    gleam test

format:
    gleam format src test

format-check:
    gleam format --check src test

lint:
    gleam check

clean:
    rm -rf build

ci: format-check lint test build

alias pr := ci

# === OPTIONAL RECIPES ===

deps:
    gleam deps download

check:
    gleam check
