defmodule ClaperWeb.EventLive.EmbedComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div
        id="collapsed-embed"
        class="bg-black py-3 px-6 text-black shadow-lg mx-auto rounded-full w-max hidden"
      >
        <div
          class="block w-full h-full cursor-pointer"
          phx-click={toggle_embed()}
          phx-target={@myself}
        >
          <div class="text-white flex space-x-2 items-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="h-6 w-6"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M14.25 9.75L16.5 12l-2.25 2.25m-4.5 0L7.5 12l2.25-2.25M6 20.25h12A2.25 2.25 0 0020.25 18V6A2.25 2.25 0 0018 3.75H6A2.25 2.25 0 003.75 6v12A2.25 2.25 0 006 20.25z"
              />
            </svg>
            <span class="font-bold">{gettext("See current web content")}</span>
          </div>
        </div>
      </div>
      <div id="extended-embed" class="bg-black w-full py-3 px-6 text-black shadow-lg rounded-md">
        <div
          class="block w-full h-full cursor-pointer"
          phx-click={toggle_embed()}
          phx-target={@myself}
        >
          <div id="embed-pane" class="float-right mt-2">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-8 w-8 text-white"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </div>

          <p class="text-xs text-gray-500 my-1">{gettext("Current web content")}</p>
          <p class="text-white text-lg font-semibold mb-4">{@embed.title}</p>
        </div>
        <div class="flex flex-col space-y-3">
          <.live_component
            id="embed-component"
            module={ClaperWeb.EventLive.EmbedIframeComponent}
            provider={@embed.provider}
            content={@embed.content}
          />
        </div>
      </div>
    </div>
    """
  end

  def toggle_embed(js \\ %JS{}) do
    js
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#collapsed-embed",
      time: 50
    )
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#extended-embed"
    )
  end
end
