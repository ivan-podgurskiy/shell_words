# ShellWords

[![CI](https://github.com/ivan-podgurskiy/shell_words/actions/workflows/ci.yml/badge.svg)](https://github.com/ivan-podgurskiy/shell_words/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Internal Elixir library skeleton: single public module, `stream_data` property tests,
Credo, Dialyzer, ExDoc-ready metadata—aligned with how mature in-repo packages are
structured (same CI shape as reference OSS libs).

## Installation

In sibling app `mix.exs`:

```elixir
def deps do
  [
    {:shell_words, path: "../shell_words"}
  ]
end
```

Adjust the path or use `git:` / organization package name as you prefer.

## Quick start

```elixir
ShellWords.example(21)
# => 42
```

Documentation is generated with `mix docs`; defaults follow `mix.exs` `docs:` (main
module page + README + changelog).

## Why?

Reuse one proven layout for every internal Hex-style library so CI, formatting, and
static analysis stay consistent without copying `mix.exs` errors by hand.

## License

MIT. See [LICENSE](LICENSE).
