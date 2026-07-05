defmodule ShellWordsPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "round trip: split(join(argv)) == {:ok, argv} for arbitrary UTF-8 argv" do
    check all(argv <- list_of(string(:utf8)), max_runs: 500) do
      assert {:ok, ^argv} = argv |> ShellWords.join() |> ShellWords.split()
    end
  end

  property "escape/1 output always parses back as exactly one word equal to the input" do
    check all(s <- string(:utf8), max_runs: 500) do
      assert {:ok, [^s]} = ShellWords.split(ShellWords.escape(s))
    end
  end

  property "hostile characters survive the round trip" do
    hostile = string([?\s, ?\t, ?\n, ?\r, ?', ?", ?\\, ?$, ?`, ?#, ?;, ?|, ?&, ?*], min_length: 1)

    check all(argv <- list_of(hostile, min_length: 1), max_runs: 500) do
      assert {:ok, ^argv} = argv |> ShellWords.join() |> ShellWords.split()
    end
  end
end
