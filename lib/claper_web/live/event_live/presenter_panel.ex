defmodule ClaperWeb.EventLive.PresenterPanel do
  @moduledoc """
  Layout of the interaction results (poll, quiz, word cloud) on the presenter
  screen.

  The results are shown in the left column, above the comments, so they never
  cover the slide. While they are not shown, a panel is kept at the same size
  but invisible and out of the layout, so that anything inside it which
  measures its container (the word cloud) keeps working.
  """

  @doc """
  CSS classes that place a results panel inside the left column.

  `visible` tells whether the results are currently shown, `chat_visible`
  whether the comments share the column with them (otherwise the results take
  the whole column).
  """
  def class(visible, chat_visible) do
    position =
      if visible,
        do: "relative shrink-0 border-b border-white/15",
        else: "absolute inset-x-0 top-0 opacity-0 pointer-events-none"

    height = if chat_visible, do: "h-[60%]", else: "h-full"

    "#{position} #{height}"
  end
end
