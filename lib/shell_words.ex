defmodule ShellWords do
  @moduledoc """
  POSIX-like shell word splitting, escaping, and joining.

  Inspired by Python's `shlex` and Ruby's `Shellwords`. This is not a shell
  interpreter: no execution, pipes, redirects, expansion, substitution,
  globbing, or comments.
  """

  # Exactly Python shlex.quote's safe set. Anything outside it (including all
  # whitespace, control characters, and non-ASCII bytes) forces quoting.
  @safe_chars ~c(ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@%+=:,./_-)

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
end
