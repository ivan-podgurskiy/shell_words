# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-05

### Added

- `ShellWords.split/2` and `ShellWords.split!/2`: POSIX-like word splitting
  with single quotes, double quotes (POSIX backslash semantics), backslash
  escaping outside quotes, empty quoted words, and adjacent segment
  concatenation.
- `ShellWords.escape/1`: `shlex.quote`-style escaping with an exact ASCII
  safe-word whitelist.
- `ShellWords.join/1`: escape and join argv into one shell-safe string.
- `ShellWords.ParseError` with `reason`, 0-based byte `position`, and
  `message` (reasons: `:unterminated_single_quote`,
  `:unterminated_double_quote`, `:trailing_escape`).
- StreamData property tests for the `split(join(argv)) == {:ok, argv}`
  round-trip guarantee.

[0.1.0]: https://github.com/ivan-podgurskiy/shell_words/releases/tag/v0.1.0
