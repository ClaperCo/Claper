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

  # Scales word-cloud font size from the option's share of total votes:
  # `base` px at 0% up to `base + range` px at 100%. Callers pick base/range
  # to fit their own display (the small moderator panel vs. the projected
  # presenter screen). Polls.calculate_percentage/2 returns a binary (via
  # :erlang.float_to_binary), not a number -- same as every other opt.percentage
  # use, which all interpolate it directly into a string ("{opt.percentage}%").
  def word_size(percentage, base \\ 14, range \\ 34)

  def word_size(percentage, base, range) when is_binary(percentage) do
    case Integer.parse(percentage) do
      {value, _rest} -> base + round(value / 100 * range)
      :error -> base
    end
  end

  def word_size(percentage, base, range) when is_number(percentage) do
    base + round(percentage / 100 * range)
  end

  def word_size(_, base, _range), do: base
end
