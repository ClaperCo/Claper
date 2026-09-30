defmodule ClaperWeb.Component.WordCloud do
  use ClaperWeb, :view_component

  @doc """
  A word cloud that the `WordCloud` hook draws in the browser. Each word goes
  out with its match key as id, so the browser shows the grouping of the
  server and never has to make up an id.
  """
  attr :id, :string, required: true
  attr :words, :list, required: true
  attr :text_color, :string, default: nil
  attr :class, :any, default: nil

  def cloud(assigns) do
    ~H"""
    <div
      id={@id}
      class={@class}
      phx-hook="WordCloud"
      phx-update="ignore"
      data-words={Jason.encode!(Enum.map(@words, &%{id: &1.key, name: &1.text, count: &1.count}))}
      data-text-color={@text_color}
    >
    </div>
    """
  end
end
