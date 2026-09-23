defmodule ClaperWeb.Helpers do
  def format_body(body) do
    url_regex = ~r/(https?:\/\/[^\s]+)/

    body
    |> String.split(url_regex, include_captures: true)
    |> Enum.map(fn
      "http" <> _rest = url ->
        escaped = url |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

        Phoenix.HTML.raw(
          ~s(<a href="#{escaped}" target="_blank" class="cursor-pointer text-primary-500 hover:underline font-medium">#{escaped}</a>)
        )

      text ->
        text
    end)
  end

  def body_without_links(text) do
    url_regex = ~r/(https?:\/\/[^\s]+)/
    String.replace(text, url_regex, "")
  end

  @doc """
  Font size in pixels for a word cloud word of the given weight, from `base` at
  0 up to `base + range` for the most frequent word at 100. The defaults fit
  the attendee view and the report; the manage preview and the projected
  screen pass their own values.
  """
  def word_size(weight, base \\ 14, range \\ 34) when is_number(weight),
    do: base + round(weight / 100 * range)
end
