defmodule ShellWords do
  @moduledoc """
  POSIX-like shell word splitting, escaping, and joining.

  Inspired by Python's `shlex` (`split`/`quote`/`join`) and Ruby's
  `Shellwords`, with an Elixir-native API:

    * `split/2` / `split!/2` — parse a shell-like command string into words
    * `escape/1` — make one argument safe as a single shell word
    * `join/1` — escape and join argv into one shell-safe string

  ## Examples

      iex> ShellWords.split(~S(cp "my file.txt" /tmp))
      {:ok, ["cp", "my file.txt", "/tmp"]}

      iex> ShellWords.join(["git", "commit", "-m", "initial commit"])
      "git commit -m 'initial commit'"

  ## Scope

  This is not a shell interpreter. There is no command execution, pipe or
  redirect handling, variable expansion, command substitution, globbing,
  or tilde expansion. Comment parsing is opt-in with `comments: true`.

  Only POSIX-like shells are targeted; there is no Windows `cmd.exe` or
  PowerShell escaping.

  ## Security

  Prefer argv-based command execution when possible:

      System.cmd("echo", ["hello world"])

  Use `escape/1` or `join/1` only when you must build a shell command
  string. The core guarantee, verified by property-based tests, is the
  round trip:

      ShellWords.split(ShellWords.join(argv)) == {:ok, argv}

  for every list of valid UTF-8 strings.

  ## Details

  Word separators are exactly ASCII space, tab, newline, and carriage
  return; Unicode whitespace is an ordinary character. Backslash-newline is
  not line continuation: the newline is kept as a literal character. Invalid
  UTF-8 bytes are preserved by `split/2`. Error positions are 0-based byte
  offsets.
  """

  alias ShellWords.ParseError

  # Exactly Python shlex.quote's safe set. Anything outside it (including all
  # whitespace, control characters, and non-ASCII bytes) forces quoting.
  @safe_chars ~c(ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@%+=:,./_-)

  @doc """
  Splits a shell-like command string into a list of words.

  Returns `{:ok, words}` or `{:error, %ShellWords.ParseError{}}`.

  Supported options:

    * `:comments` — when `true`, an unquoted, unescaped `#` starts a comment
      only at the start of a word. The comment runs to the next newline or
      the end of input. Defaults to `false`.

  Unknown options raise `ArgumentError`.

  ## Examples

      iex> ShellWords.split("ls -la /tmp")
      {:ok, ["ls", "-la", "/tmp"]}

      iex> ShellWords.split("")
      {:ok, []}

      iex> ShellWords.split("echo hello # comment", comments: true)
      {:ok, ["echo", "hello"]}

  """
  @spec split(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, ParseError.t()}
  def split(input, opts \\ [])

  def split(input, opts) when is_binary(input) and is_list(opts) do
    comments? = validate_opts!(opts)

    bare(input, 0, "", [], false, comments?)
  end

  @doc """
  Like `split/2`, but returns the word list directly and raises
  `ShellWords.ParseError` on parse errors.

  ## Examples

      iex> ShellWords.split!(~S(echo "hello world"))
      ["echo", "hello world"]

  """
  @spec split!(String.t(), keyword()) :: [String.t()]
  def split!(input, opts \\ []) do
    case split(input, opts) do
      {:ok, words} -> words
      {:error, error} -> raise error
    end
  end

  @doc """
  Escapes a string so a POSIX shell parses it back as a single word with the
  original content.

  Returns the string unchanged only when it is non-empty and consists solely
  of unambiguously safe ASCII characters; otherwise wraps it in single quotes,
  escaping embedded single quotes. The empty string becomes `"''"`.

  Output style matches Python's `shlex.quote` (single-quote wrapping), not
  Ruby's backslash-style `Shellwords.escape`.

  ## Examples

      iex> ShellWords.escape("hello")
      "hello"

      iex> ShellWords.escape("hello world")
      "'hello world'"

      iex> ShellWords.escape("")
      "''"

  """
  @spec escape(String.t()) :: String.t()
  def escape(""), do: "''"

  def escape(arg) when is_binary(arg) do
    if safe_bare_word?(arg) do
      arg
    else
      "'" <> String.replace(arg, "'", ~S('"'"')) <> "'"
    end
  end

  @doc """
  Escapes each argument with `escape/1` and joins them with single spaces,
  producing one shell-safe command string.

  ## Examples

      iex> ShellWords.join(["echo", "hello world"])
      "echo 'hello world'"

      iex> ShellWords.join([])
      ""

  """
  @spec join([String.t()]) :: String.t()
  def join(argv) when is_list(argv) do
    Enum.map_join(argv, " ", &escape/1)
  end

  defp safe_bare_word?(<<>>), do: true
  defp safe_bare_word?(<<c, rest::binary>>) when c in @safe_chars, do: safe_bare_word?(rest)
  defp safe_bare_word?(_), do: false

  defp validate_opts!(opts), do: parse_opts(opts, false)

  defp parse_opts([], comments?), do: comments?

  defp parse_opts([{:comments, comments?} | opts], _comments?) when is_boolean(comments?) do
    parse_opts(opts, comments?)
  end

  defp parse_opts([{:comments, value} | _opts], _comments?) do
    raise ArgumentError, "expected :comments to be a boolean, got: #{inspect(value)}"
  end

  defp parse_opts([opt | _opts], _comments?) do
    raise ArgumentError, "unknown option: #{inspect(opt)}"
  end

  # Word separators: exactly ASCII space, tab, newline, carriage return.
  @whitespace ~c( \t\n\r)

  # Characters whose backslash-escape is honored inside double quotes
  # (POSIX 2.2.3); a backslash before anything else is preserved literally.
  @dquote_escapable ~c($`"\\)

  # State: bare — outside any quotes.
  # word is the word built so far; started? distinguishes "no word open"
  # from "word open but currently empty" (needed for '' and "").
  defp bare(<<>>, _pos, word, acc, started?, _comments?) do
    {:ok, Enum.reverse(finish_word(word, acc, started?))}
  end

  defp bare(<<"\\">>, pos, _word, _acc, _started?, _comments?) do
    {:error, ParseError.new(:trailing_escape, pos)}
  end

  defp bare(<<"\\", c, rest::binary>>, pos, word, acc, _started?, comments?) do
    bare(rest, pos + 2, <<word::binary, c>>, acc, true, comments?)
  end

  defp bare(<<"'", rest::binary>>, pos, word, acc, _started?, comments?) do
    single(rest, pos + 1, pos, word, acc, comments?)
  end

  defp bare(<<"\"", rest::binary>>, pos, word, acc, _started?, comments?) do
    double(rest, pos + 1, pos, word, acc, comments?)
  end

  defp bare(<<"#", rest::binary>>, pos, word, acc, false, true) do
    {rest, pos} = skip_comment(rest, pos + 1)

    bare(rest, pos, word, acc, false, true)
  end

  defp bare(<<c, rest::binary>>, pos, word, acc, started?, comments?) when c in @whitespace do
    bare(rest, pos + 1, "", finish_word(word, acc, started?), false, comments?)
  end

  defp bare(<<c, rest::binary>>, pos, word, acc, _started?, comments?) do
    bare(rest, pos + 1, <<word::binary, c>>, acc, true, comments?)
  end

  # State: single — inside single quotes. Everything is literal until the
  # closing quote; open_pos is the offset of the opening quote.
  defp single(<<>>, _pos, open_pos, _word, _acc, _comments?) do
    {:error, ParseError.new(:unterminated_single_quote, open_pos)}
  end

  defp single(<<"'", rest::binary>>, pos, _open_pos, word, acc, comments?) do
    bare(rest, pos + 1, word, acc, true, comments?)
  end

  defp single(<<c, rest::binary>>, pos, open_pos, word, acc, comments?) do
    single(rest, pos + 1, open_pos, <<word::binary, c>>, acc, comments?)
  end

  # State: double — inside double quotes. Backslash escapes only
  # @dquote_escapable; any other backslash sequence passes through with the
  # backslash preserved. open_pos is the offset of the opening quote.
  defp double(<<>>, _pos, open_pos, _word, _acc, _comments?) do
    {:error, ParseError.new(:unterminated_double_quote, open_pos)}
  end

  defp double(<<"\\">>, _pos, open_pos, _word, _acc, _comments?) do
    {:error, ParseError.new(:unterminated_double_quote, open_pos)}
  end

  defp double(<<"\\", c, rest::binary>>, pos, open_pos, word, acc, comments?)
       when c in @dquote_escapable do
    double(rest, pos + 2, open_pos, <<word::binary, c>>, acc, comments?)
  end

  defp double(<<"\\", c, rest::binary>>, pos, open_pos, word, acc, comments?) do
    double(rest, pos + 2, open_pos, <<word::binary, ?\\, c>>, acc, comments?)
  end

  defp double(<<"\"", rest::binary>>, pos, _open_pos, word, acc, comments?) do
    bare(rest, pos + 1, word, acc, true, comments?)
  end

  defp double(<<c, rest::binary>>, pos, open_pos, word, acc, comments?) do
    double(rest, pos + 1, open_pos, <<word::binary, c>>, acc, comments?)
  end

  defp skip_comment(<<>>, pos), do: {<<>>, pos}
  defp skip_comment(<<"\n", rest::binary>>, pos), do: {rest, pos + 1}
  defp skip_comment(<<_c, rest::binary>>, pos), do: skip_comment(rest, pos + 1)

  defp finish_word(_word, acc, false), do: acc
  defp finish_word(word, acc, true), do: [word | acc]
end
