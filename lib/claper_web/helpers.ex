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
  Formats a slider average or median with at most one decimal, or as a dash
  while nobody has answered.
  """
  def format_number(nil), do: "-"

  def format_number(number) do
    rounded = Float.round(number / 1, 1)

    if rounded == trunc(rounded),
      do: Integer.to_string(trunc(rounded)),
      else: Float.to_string(rounded)
  end
end
