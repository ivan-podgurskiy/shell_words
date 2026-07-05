defmodule ShellWords.ParseError do
  @moduledoc """
  Error returned by `ShellWords.split/2` and raised by `ShellWords.split!/2`
  when the input cannot be parsed.

  Fields:

    * `:reason` — one of `:unterminated_single_quote`,
      `:unterminated_double_quote`, or `:trailing_escape`
    * `:position` — 0-based byte offset into the input binary. For
      unterminated quotes this is the offset of the opening quote character;
      for a trailing escape it is the offset of the backslash.
    * `:message` — human-readable description including the position

  All three fields are always populated.
  """

  defexception [:reason, :position, :message]

  @type reason ::
          :unterminated_single_quote
          | :unterminated_double_quote
          | :trailing_escape

  @type t :: %__MODULE__{
          reason: reason(),
          position: non_neg_integer(),
          message: String.t()
        }

  @doc false
  @spec new(reason(), non_neg_integer()) :: t()
  def new(reason, position) when is_integer(position) and position >= 0 do
    %__MODULE__{reason: reason, position: position, message: message_for(reason, position)}
  end

  defp message_for(:unterminated_single_quote, pos),
    do: "unterminated single quote at byte #{pos}"

  defp message_for(:unterminated_double_quote, pos),
    do: "unterminated double quote at byte #{pos}"

  defp message_for(:trailing_escape, pos), do: "trailing escape at byte #{pos}"
end
