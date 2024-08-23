defmodule ClaperWeb.EventLive.EmbedIframeComponent do
  use ClaperWeb, :live_component

  def render(assigns) do
    ~H"""
    <div id={@id} class="h-full w-full">
      <%= case @provider do %>
        <% "youtube" -> %>
          <iframe
            src={"https://www.youtube.com/embed/#{@content |> String.split("youtu.be/") |> Enum.at(1)}"}
            frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            referrerpolicy="strict-origin-when-cross-origin"
            allowfullscreen
          >
          </iframe>
        <% "vimeo" -> %>
          <iframe
            src={"https://player.vimeo.com/video/#{@content |> String.split("vimeo.com/") |> Enum.at(1)}"}
            frameborder="0"
            allow="autoplay; fullscreen; picture-in-picture"
            allowfullscreen
          >
          </iframe>
        <% "canva" -> %>
          <iframe
            src={"#{@content}?embed"}
            frameborder="0"
            allowfullscreen="allowfullscreen"
            allow="fullscreen"
          >
          </iframe>
        <% "googleslides" -> %>
          <iframe
            src={"#{@content |> String.replace("/pub", "/embed")}"}
            frameborder="0"
            allowfullscreen="allowfullscreen"
            allow="fullscreen"
          >
          </iframe>
        <% "custom" -> %>
          <%= raw(@content) %>
      <% end %>
    </div>
    """
  end
end
