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
end
