defmodule ShellWords.ParseErrorTest do
  use ExUnit.Case, async: true

  alias ShellWords.ParseError

  test "new/2 populates reason, position, and message for each reason" do
    assert %ParseError{
             reason: :unterminated_single_quote,
             position: 5,
             message: "unterminated single quote at byte 5"
           } = ParseError.new(:unterminated_single_quote, 5)

    assert %ParseError{
             reason: :unterminated_double_quote,
             position: 0,
             message: "unterminated double quote at byte 0"
           } = ParseError.new(:unterminated_double_quote, 0)

    assert %ParseError{
             reason: :trailing_escape,
             position: 10,
             message: "trailing escape at byte 10"
           } = ParseError.new(:trailing_escape, 10)
  end

  test "is raisable as an exception with its message" do
    error = ParseError.new(:trailing_escape, 3)

    assert_raise ParseError, "trailing escape at byte 3", fn ->
      raise error
    end
  end
end
