defmodule ClaperWeb.Helpers do
  def format_body(body) do
    url_regex = ~r/(https?:\/\/[^\s]+)/

    body
    |> String.split(url_regex, include_captures: true)
    |> Enum.map(fn
      "http" <> _rest = url ->
        Phoenix.HTML.raw(
          ~s(<a href="#{url}" target="_blank" class="cursor-pointer text-primary-500 hover:underline font-medium">#{url}</a>)
        )

      text ->
        text
    end)
  end

  def body_without_links(text) do
    url_regex = ~r/(https?:\/\/[^\s]+)/
    String.replace(text, url_regex, "")
  end
end
