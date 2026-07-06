# Roadmap

Planned direction for `shell_words`. Dates are intentions, not promises;
scope may shift based on feedback and real-world usage.

## v0.1.0 — Initial release (current)

Status: complete, pending publication to Hex.

- `split/2` and `split!/2` with POSIX-like word rules: whitespace
  separation, single quotes, double quotes with POSIX backslash semantics,
  backslash escaping outside quotes, empty quoted words, adjacent segment
  concatenation.
- `escape/1` (`shlex.quote`-style single-quote wrapping) and `join/1`.
- `ShellWords.ParseError` with `reason`, 0-based byte `position`, and
  `message`.
- Property-tested round-trip guarantee:
  `split(join(argv)) == {:ok, argv}` for arbitrary valid-UTF-8 argv.

## v0.2.0 — Comments and edge-case decisions

- `comments: true` option for `split/2` and `split!/2`. Semantics: an
  unquoted, unescaped `#` starts a comment only at the start of a word
  (start of input or immediately after unquoted whitespace); the comment
  runs to the next newline or end of input. `echo hello#world` does NOT
  start a comment; `echo hello #world` does. Default stays
  `comments: false`.
- Decide and document invalid-UTF-8 handling: explicit error vs byte
  pass-through (currently unspecified).
- Decide and document backslash-newline continuation (currently a literal
  newline outside quotes mid-input, `:trailing_escape` at end of input,
  literal pass-through inside double quotes).
- Compatibility test suite comparing outputs against Python `shlex` and
  Ruby `Shellwords`.

## v1.0.0 — Stable API

- Public API frozen; semver guarantees from here on.
- Comprehensive test coverage, no known parse bugs in supported scope.
- Security notes reviewed and finalized.

## Ideas beyond 1.0 (no commitment)

- Lower-level lexer API: `ShellWords.tokenize/2`, `ShellWords.valid?/1`.
- Parsing modes (`mode: :posix`) if a second dialect ever justifies it.
- Platform-specific escaping modules (PowerShell, `cmd.exe`) — only if
  there is clear demand; POSIX remains the core scope.

## Non-goals

`shell_words` will not become a shell interpreter: no command execution,
pipes, redirects, variable expansion, command substitution, globbing,
tilde expansion, or heredocs. These belong to a shell parser or command
runner, not a shell words library.
