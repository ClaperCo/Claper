defmodule ClaperWeb.EventLive.EmbedIframeComponent do
  use ClaperWeb, :live_component

  alias Claper.Embeds.Embed

  def render(assigns) do
    iframe_attrs =
      if assigns.provider == "custom" do
        case Embed.custom_iframe_attributes(assigns.content) do
          {:ok, attrs} -> attrs
          :error -> nil
        end
      end

    # Stored links are re-validated: rows may predate host validation.
    provider_url =
      case Embed.provider_embed_url(assigns.provider, assigns.content) do
        {:ok, url} -> url
        :error -> nil
      end

    assigns = assign(assigns, iframe_attrs: iframe_attrs, provider_url: provider_url)

    ~H"""
    <div id={@id} class="h-full w-full">
      <%= case @provider do %>
        <% "youtube" -> %>
          <iframe
            :if={@provider_url}
            class="h-full w-full"
            title={@title}
            src={@provider_url}
            frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            referrerpolicy="strict-origin-when-cross-origin"
            allowfullscreen
          >
          </iframe>
        <% "vimeo" -> %>
          <iframe
            :if={@provider_url}
            class="h-full w-full"
            title={@title}
            src={@provider_url}
            frameborder="0"
            allow="autoplay; fullscreen; picture-in-picture"
            allowfullscreen
          >
          </iframe>
        <% provider when provider in ["canva", "googleslides"] -> %>
          <iframe
            :if={@provider_url}
            class="h-full w-full"
            title={@title}
            src={@provider_url}
            frameborder="0"
            allowfullscreen="allowfullscreen"
            allow="fullscreen"
          >
          </iframe>
        <% "custom" -> %>
          <iframe :if={@iframe_attrs} {@iframe_attrs}></iframe>
      <% end %>
    </div>
    """
  end
end
