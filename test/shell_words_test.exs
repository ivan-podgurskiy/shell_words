defmodule ShellWordsTest do
  use ExUnit.Case, async: true

  doctest ShellWords

  describe "escape/1" do
    test "empty string returns two single quotes" do
      assert ShellWords.escape("") == "''"
    end

    test "safe bare words are returned unchanged" do
      assert ShellWords.escape("hello") == "hello"
      assert ShellWords.escape("ABCxyz019") == "ABCxyz019"
      # every non-alphanumeric character of the safe whitelist
      assert ShellWords.escape("@%+=:,./_-") == "@%+=:,./_-"
      assert ShellWords.escape("/usr/local/bin/elixir") == "/usr/local/bin/elixir"

      assert ShellWords.escape("user@host.example,a=b_c-d:e+f%g") ==
               "user@host.example,a=b_c-d:e+f%g"
    end

    test "whitespace forces quoting" do
      assert ShellWords.escape("hello world") == "'hello world'"
      assert ShellWords.escape("tab\there") == "'tab\there'"
      assert ShellWords.escape("line\nbreak") == "'line\nbreak'"
    end

    test "shell metacharacters force quoting" do
      assert ShellWords.escape("hello; rm -rf /") == "'hello; rm -rf /'"
      assert ShellWords.escape("a|b") == "'a|b'"
      assert ShellWords.escape("$HOME") == "'$HOME'"
      assert ShellWords.escape("`whoami`") == "'`whoami`'"
      assert ShellWords.escape("*.txt") == "'*.txt'"
      assert ShellWords.escape(~S(back\slash)) == ~S('back\slash')
      assert ShellWords.escape(~S(say "hi")) == ~S('say "hi"')
    end

    test "embedded single quotes use the close-escape-reopen pattern" do
      assert ShellWords.escape("don't") == ~S('don'"'"'t')
      assert ShellWords.escape("''") == ~S(''"'"''"'"'')
    end

    test "non-ASCII Unicode is always quoted" do
      assert ShellWords.escape("привет") == ~S('привет')
      assert ShellWords.escape("naïve") == ~S('naïve')
      assert ShellWords.escape("日本語") == ~S('日本語')
    end
  end

  describe "join/1" do
    test "empty argv returns empty string" do
      assert ShellWords.join([]) == ""
    end

    test "single safe argument" do
      assert ShellWords.join(["ls"]) == "ls"
    end

    test "multiple arguments, quoting only where needed" do
      assert ShellWords.join(["echo", "hello world"]) == "echo 'hello world'"

      assert ShellWords.join(["git", "commit", "-m", "initial commit"]) ==
               "git commit -m 'initial commit'"
    end

    test "arguments with quotes and empties" do
      assert ShellWords.join(["printf", "%s", "don't", ""]) ==
               ~S(printf %s 'don'"'"'t' '')
    end
  end

  describe "split/2 — bare words and whitespace" do
    test "simple words" do
      assert ShellWords.split("echo hello") == {:ok, ["echo", "hello"]}
      assert ShellWords.split("ls -la /tmp") == {:ok, ["ls", "-la", "/tmp"]}
    end

    test "runs of whitespace collapse; leading/trailing ignored" do
      assert ShellWords.split("  echo    hello  ") == {:ok, ["echo", "hello"]}
    end

    test "tab, newline, and carriage return separate words" do
      assert ShellWords.split("a\tb\nc\rd") == {:ok, ["a", "b", "c", "d"]}
      assert ShellWords.split("a \t\r\n b") == {:ok, ["a", "b"]}
    end

    test "empty and whitespace-only input yield an empty list" do
      assert ShellWords.split("") == {:ok, []}
      assert ShellWords.split("   \t\n\r ") == {:ok, []}
    end

    test "Unicode whitespace is an ordinary character, not a separator" do
      # U+00A0 no-break space, U+2003 em space
      assert ShellWords.split("a\u00A0b") == {:ok, ["a\u00A0b"]}
      assert ShellWords.split("a\u2003b") == {:ok, ["a\u2003b"]}
    end

    test "multibyte UTF-8 words reassemble intact" do
      assert ShellWords.split("caf\u00E9 \u00FCber") == {:ok, ["caf\u00E9", "\u00FCber"]}
    end

    test "# is an ordinary character" do
      assert ShellWords.split("echo hello # comment") ==
               {:ok, ["echo", "hello", "#", "comment"]}
    end

    test "unknown options raise ArgumentError" do
      assert_raise ArgumentError, fn ->
        ShellWords.split("echo", comments: true)
      end
    end

    test "empty options list is accepted" do
      assert ShellWords.split("echo", []) == {:ok, ["echo"]}
    end
  end

  describe "split/2 — single quotes" do
    test "preserves whitespace inside quotes" do
      assert ShellWords.split(~S(echo 'hello world')) == {:ok, ["echo", "hello world"]}
    end

    test "everything is literal inside single quotes, including backslashes" do
      assert ShellWords.split(~S(echo 'a\b')) == {:ok, ["echo", ~S(a\b)]}
      assert ShellWords.split(~S(echo '$HOME `x` "y"')) == {:ok, ["echo", ~S($HOME `x` "y")]}
    end

    test "newlines inside single quotes are preserved" do
      assert ShellWords.split("echo 'line1\nline2'") == {:ok, ["echo", "line1\nline2"]}
    end

    test "empty single-quoted string produces an empty word" do
      assert ShellWords.split("echo ''") == {:ok, ["echo", ""]}
    end

    test "unterminated single quote reports the opening quote position" do
      assert {:error, %ShellWords.ParseError{reason: :unterminated_single_quote, position: 5}} =
               ShellWords.split(~S(echo 'hello))

      assert {:error, %ShellWords.ParseError{reason: :unterminated_single_quote, position: 0}} =
               ShellWords.split("'")
    end
  end

  describe "split/2 — double quotes" do
    test "preserves whitespace inside quotes" do
      assert ShellWords.split(~S(echo "hello world")) == {:ok, ["echo", "hello world"]}
    end

    test "the four POSIX escapes: dollar, backtick, double quote, backslash" do
      assert ShellWords.split(~S(echo "price: \$5")) == {:ok, ["echo", "price: $5"]}
      assert ShellWords.split(~S(echo "tick: \`x\`")) == {:ok, ["echo", "tick: `x`"]}
      assert ShellWords.split(~S(echo "hello \"Ivan\"")) == {:ok, ["echo", ~S(hello "Ivan")]}
      assert ShellWords.split(~S(echo "a\\b")) == {:ok, ["echo", ~S(a\b)]}
    end

    test "backslash before any other character passes both through literally" do
      assert ShellWords.split(~S(echo "back\slash")) == {:ok, ["echo", ~S(back\slash)]}
      assert ShellWords.split(~S(echo "a\ b")) == {:ok, ["echo", ~S(a\ b)]}
      # backslash-newline is NOT line continuation: both characters survive
      assert ShellWords.split("echo \"a\\\nb\"") == {:ok, ["echo", "a\\\nb"]}
      # backslash before a multibyte character: byte-level pass-through stays intact
      assert ShellWords.split(~S(echo "a\é")) == {:ok, ["echo", ~S(a\é)]}
    end

    test "empty double-quoted string produces an empty word" do
      assert ShellWords.split(~S(echo "")) == {:ok, ["echo", ""]}
    end

    test "newlines inside double quotes are preserved" do
      assert ShellWords.split("echo \"line1\nline2\"") == {:ok, ["echo", "line1\nline2"]}
    end

    test "unterminated double quote reports the opening quote position" do
      assert {:error, %ShellWords.ParseError{reason: :unterminated_double_quote, position: 5}} =
               ShellWords.split(~S(echo "hello))

      # a lone trailing backslash inside double quotes is still an
      # unterminated double quote (anchored at the opening quote)
      assert {:error, %ShellWords.ParseError{reason: :unterminated_double_quote, position: 5}} =
               ShellWords.split("echo \"hello\\")
    end
  end

  describe "split/2 — backslash outside quotes" do
    test "escapes the next character unconditionally" do
      assert ShellWords.split(~S(echo hello\ world)) == {:ok, ["echo", "hello world"]}
      assert ShellWords.split(~S(echo \#)) == {:ok, ["echo", "#"]}
      assert ShellWords.split(~S(echo \')) == {:ok, ["echo", "'"]}
      assert ShellWords.split(~S(echo \")) == {:ok, ["echo", ~S(")]}
      assert ShellWords.split(~S(echo a\\b)) == {:ok, ["echo", ~S(a\b)]}
    end

    test "an escaped newline is a literal newline, not continuation" do
      assert ShellWords.split("echo a\\\nb") == {:ok, ["echo", "a\nb"]}
    end

    test "a trailing backslash reports its own position" do
      assert {:error, %ShellWords.ParseError{reason: :trailing_escape, position: 10}} =
               ShellWords.split("echo hello\\")

      assert {:error, %ShellWords.ParseError{reason: :trailing_escape, position: 0}} =
               ShellWords.split("\\")
    end
  end

  describe "split/2 — adjacency" do
    test "adjacent quoted and unquoted segments form one word" do
      assert ShellWords.split(~S(echo foo"bar"baz)) == {:ok, ["echo", "foobarbaz"]}
      assert ShellWords.split(~S(echo 'foo'"bar")) == {:ok, ["echo", "foobar"]}
      assert ShellWords.split(~S(echo foo'bar')) == {:ok, ["echo", "foobar"]}
      assert ShellWords.split(~S(a"b"'c'\ d)) == {:ok, ["abc d"]}
    end

    test "empty quoted segments adjacent to content do not split the word" do
      assert ShellWords.split(~S(echo foo""bar)) == {:ok, ["echo", "foobar"]}
      assert ShellWords.split(~S(echo ''"")) == {:ok, ["echo", ""]}
    end

    test "consecutive quoted empties separated by space are separate empty words" do
      assert ShellWords.split(~S(echo "" '')) == {:ok, ["echo", "", ""]}
    end

    test "a standalone escaped whitespace character forms its own word" do
      assert ShellWords.split(~S(echo \  b)) == {:ok, ["echo", " ", "b"]}
    end
  end
end
