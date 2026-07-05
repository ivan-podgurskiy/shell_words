defmodule ShellWords do
  @moduledoc """
  POSIX-like shell word splitting, escaping, and joining.

  Inspired by Python's `shlex` and Ruby's `Shellwords`. This is not a shell
  interpreter: no execution, pipes, redirects, expansion, substitution,
  globbing, or comments.
  """

  alias ShellWords.ParseError

  # Exactly Python shlex.quote's safe set. Anything outside it (including all
  # whitespace, control characters, and non-ASCII bytes) forces quoting.
  @safe_chars ~c(ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@%+=:,./_-)

  @doc """
  Splits a shell-like command string into a list of words.

  Returns `{:ok, words}` or `{:error, %ShellWords.ParseError{}}`.

  No options are supported yet; the `opts` argument exists to keep the arity
  stable for future releases. Unknown options raise `ArgumentError`.

  ## Examples

      iex> ShellWords.split("ls -la /tmp")
      {:ok, ["ls", "-la", "/tmp"]}

      iex> ShellWords.split("")
      {:ok, []}

  """
  @spec split(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, ParseError.t()}
  def split(input, opts \\ [])

  def split(input, opts) when is_binary(input) and is_list(opts) do
    validate_opts!(opts)
    bare(input, 0, "", [], false)
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

  defp validate_opts!([]), do: :ok

  defp validate_opts!([opt | _]) do
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
  defp bare(<<>>, _pos, word, acc, started?) do
    {:ok, Enum.reverse(finish_word(word, acc, started?))}
  end

  defp bare(<<"\\">>, pos, _word, _acc, _started?) do
    {:error, ParseError.new(:trailing_escape, pos)}
  end

  defp bare(<<"\\", c, rest::binary>>, pos, word, acc, _started?) do
    bare(rest, pos + 2, <<word::binary, c>>, acc, true)
  end

  defp bare(<<"'", rest::binary>>, pos, word, acc, _started?) do
    single(rest, pos + 1, pos, word, acc)
  end

  defp bare(<<"\"", rest::binary>>, pos, word, acc, _started?) do
    double(rest, pos + 1, pos, word, acc)
  end

  defp bare(<<c, rest::binary>>, pos, word, acc, started?) when c in @whitespace do
    bare(rest, pos + 1, "", finish_word(word, acc, started?), false)
  end

  defp bare(<<c, rest::binary>>, pos, word, acc, _started?) do
    bare(rest, pos + 1, <<word::binary, c>>, acc, true)
  end

  # State: single — inside single quotes. Everything is literal until the
  # closing quote; open_pos is the offset of the opening quote.
  defp single(<<>>, _pos, open_pos, _word, _acc) do
    {:error, ParseError.new(:unterminated_single_quote, open_pos)}
  end

  defp single(<<"'", rest::binary>>, pos, _open_pos, word, acc) do
    bare(rest, pos + 1, word, acc, true)
  end

  defp single(<<c, rest::binary>>, pos, open_pos, word, acc) do
    single(rest, pos + 1, open_pos, <<word::binary, c>>, acc)
  end

  # State: double — inside double quotes. Backslash escapes only
  # @dquote_escapable; any other backslash sequence passes through with the
  # backslash preserved. open_pos is the offset of the opening quote.
  defp double(<<>>, _pos, open_pos, _word, _acc) do
    {:error, ParseError.new(:unterminated_double_quote, open_pos)}
  end

  defp double(<<"\\">>, _pos, open_pos, _word, _acc) do
    {:error, ParseError.new(:unterminated_double_quote, open_pos)}
  end

  defp double(<<"\\", c, rest::binary>>, pos, open_pos, word, acc)
       when c in @dquote_escapable do
    double(rest, pos + 2, open_pos, <<word::binary, c>>, acc)
  end

  defp double(<<"\\", c, rest::binary>>, pos, open_pos, word, acc) do
    double(rest, pos + 2, open_pos, <<word::binary, ?\\, c>>, acc)
  end

  defp double(<<"\"", rest::binary>>, pos, _open_pos, word, acc) do
    bare(rest, pos + 1, word, acc, true)
  end

  defp double(<<c, rest::binary>>, pos, open_pos, word, acc) do
    double(rest, pos + 1, open_pos, <<word::binary, c>>, acc)
  end

  defp finish_word(_word, acc, false), do: acc
  defp finish_word(word, acc, true), do: [word | acc]
end
