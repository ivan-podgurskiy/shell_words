defmodule ShellWordsCompatibilityTest do
  use ExUnit.Case, async: true

  @split_cases [
    {"simple words", "echo hello", ["echo", "hello"]},
    {"quoted whitespace", ~S(echo "hello world"), ["echo", "hello world"]},
    {"single quotes", ~S(echo 'hello world'), ["echo", "hello world"]},
    {"escaped whitespace", ~S(echo hello\ world), ["echo", "hello world"]},
    {"adjacent segments", ~S(echo foo"bar"'baz'), ["echo", "foobarbaz"]},
    {"escaped hash", ~S(echo \#), ["echo", "#"]}
  ]

  @comment_cases [
    {"whole-line comment", "# comment\nnext word", ["next", "word"]},
    {"word-start comment", "echo hello # comment", ["echo", "hello"]}
  ]

  describe "Python shlex compatibility" do
    @tag :external_tool
    test "split/2 matches shlex.split for supported non-comment cases" do
      require_tool!("python3")

      for {_name, input, expected} <- @split_cases do
        assert_python_split(input, false, expected)
        assert ShellWords.split(input) == {:ok, expected}
      end
    end

    @tag :external_tool
    test "comments: true matches shlex.split comments behavior" do
      require_tool!("python3")

      for {_name, input, expected} <- @comment_cases do
        assert_python_split(input, true, expected)
        assert ShellWords.split(input, comments: true) == {:ok, expected}
      end
    end
  end

  describe "Ruby Shellwords compatibility" do
    @tag :external_tool
    test "split/2 matches Shellwords.split for supported non-comment cases" do
      require_tool!("ruby")

      for {_name, input, expected} <- @split_cases do
        assert_ruby_split(input, expected)
        assert ShellWords.split(input) == {:ok, expected}
      end
    end
  end

  defp require_tool!(name) do
    if System.find_executable(name) == nil do
      flunk("#{name} is required for this compatibility test")
    end
  end

  defp assert_python_split(input, comments?, expected) do
    python_comments? = if comments?, do: "True", else: "False"

    script = """
    import shlex
    import sys

    actual = shlex.split(sys.argv[1], comments=#{python_comments?})
    expected = sys.argv[2:]

    if actual != expected:
        print(f"expected {expected!r}, got {actual!r}", file=sys.stderr)
        sys.exit(1)
    """

    assert {"", 0} =
             System.cmd("python3", ["-c", script, input | expected], stderr_to_stdout: true)
  end

  defp assert_ruby_split(input, expected) do
    script = """
    require 'shellwords'

    actual = Shellwords.split(ARGV.fetch(0))
    expected = ARGV.drop(1)

    unless actual == expected
      warn "expected \#{expected.inspect}, got \#{actual.inspect}"
      exit 1
    end
    """

    assert {"", 0} = System.cmd("ruby", ["-e", script, input | expected], stderr_to_stdout: true)
  end
end
