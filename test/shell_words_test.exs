defmodule ShellWordsTest do
  use ExUnit.Case
  doctest ShellWords

  test "example/1 doubles integers" do
    assert ShellWords.example(3) == 6
  end
end
