# ShellWords

[![CI](https://github.com/ivan-podgurskiy/shell_words/actions/workflows/ci.yml/badge.svg)](https://github.com/ivan-podgurskiy/shell_words/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

POSIX-like shell word splitting, escaping, and joining for Elixir — the
practical equivalent of Python's `shlex.split/quote/join` and Ruby's
`Shellwords`, with zero runtime dependencies.

```elixir
ShellWords.split(~S(cp "my file.txt" /tmp))
# {:ok, ["cp", "my file.txt", "/tmp"]}

ShellWords.join(["git", "commit", "-m", "initial commit"])
# "git commit -m 'initial commit'"
```

## Installation

Add `shell_words` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:shell_words, "~> 0.2.0"}
  ]
end
```

## Usage

### split/2

Parses a shell-like command string into words. Returns `{:ok, words}` or
`{:error, %ShellWords.ParseError{}}` with a reason and a 0-based byte
position.

```elixir
ShellWords.split(~S(echo "hello world"))
# {:ok, ["echo", "hello world"]}

ShellWords.split(~S(echo hello\ world))
# {:ok, ["echo", "hello world"]}

ShellWords.split(~S(echo "hello))
# {:error, %ShellWords.ParseError{reason: :unterminated_double_quote, position: 5, ...}}
```

Supported syntax: whitespace-separated words (ASCII space, tab, newline,
carriage return); single quotes (fully literal); double quotes with POSIX
backslash semantics (`\` escapes `$`, `` ` ``, `"`, `\`; any other
backslash sequence passes through literally); backslash escaping outside
quotes; empty quoted words; adjacent segment concatenation.

Comments are disabled by default. Pass `comments: true` to treat an
unquoted, unescaped `#` as a comment starter only at the start of a word:

```elixir
ShellWords.split("echo hello # comment", comments: true)
# {:ok, ["echo", "hello"]}

ShellWords.split("echo hello#world", comments: true)
# {:ok, ["echo", "hello#world"]}
```

### split!/2

Same as `split/2` but returns the list directly and raises
`ShellWords.ParseError` on invalid input.

```elixir
ShellWords.split!(~S(echo "hello world"))
# ["echo", "hello world"]
```

### escape/1

Escapes one argument so a POSIX shell parses it back as a single word with
the original content. Safe bare words (non-empty, only
`A-Z a-z 0-9 @ % + = : , . / _ -`) pass through unchanged; everything else
is single-quoted. The empty string becomes `''`.

```elixir
ShellWords.escape("hello")        # "hello"
ShellWords.escape("hello world")  # "'hello world'"
ShellWords.escape("don't")        # ~S('don'"'"'t')
ShellWords.escape("привет")       # ~S('привет')
```

### join/1

Escapes each argument and joins with spaces.

```elixir
ShellWords.join(["echo", "hello world"])
# "echo 'hello world'"
```

## Security Notes

Prefer argv-based command execution when possible. Use `ShellWords.escape/1`
or `ShellWords.join/1` only when you need to build a shell command string.

```elixir
# Safest: no shell involved
System.cmd("echo", ["hello world"])

# When a shell string is unavoidable, escape every argument
System.cmd("sh", ["-c", ShellWords.join(["echo", user_input])])
```

The core guarantee, verified with property-based tests over arbitrary UTF-8
input, is the round trip:

```elixir
ShellWords.split(ShellWords.join(argv)) == {:ok, argv}
```

ShellWords targets POSIX-like shells. It does not provide Windows `cmd.exe`
or PowerShell escaping.

## What This Library Does Not Do

No command execution, pipes, redirects, variable expansion (`$HOME`),
command substitution (`$(...)`), globbing (`*.txt`), tilde expansion,
heredocs, or Bash-specific syntax. Backslash-newline line continuation is
not supported; an escaped newline is preserved literally. `split/2`
preserves invalid UTF-8 bytes instead of validating or rewriting them.

## Comparison with Python shlex and Ruby Shellwords

| | Python | Ruby | ShellWords |
|---|---|---|---|
| Split | `shlex.split(s)` | `Shellwords.split(s)` | `ShellWords.split(s)` / `split!(s)` |
| Escape | `shlex.quote(s)` | `Shellwords.escape(s)` | `ShellWords.escape(s)` |
| Join | `shlex.join(argv)` | `Shellwords.join(argv)` | `ShellWords.join(argv)` |

The function is named `escape/1` (not `quote/1`) because `quote` is an
Elixir special form.

**Escaping style differs from Ruby.** Ruby's `Shellwords.escape` produces
backslash-style output (`It\'s\ better`); `ShellWords.escape/1` produces
single-quote wrapping like Python's `shlex.quote` (`'It'"'"'s better'`).
Both parse back to the original argument in a POSIX shell — the output just
looks different.

## License

MIT. See [LICENSE](LICENSE).
