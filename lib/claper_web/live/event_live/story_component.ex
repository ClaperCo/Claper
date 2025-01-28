defmodule ClaperWeb.EventLive.StoryComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div
        id="collapsed-story"
        class="bg-gray-900 py-3 px-6 text-black shadow-lg mx-auto rounded-full w-max hidden"
      >
        <div
          class="block w-full h-full cursor-pointer"
          phx-click={toggle_story()}
          phx-target={@myself}
        >
          <div class="text-white flex space-x-2 items-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
            <span class="font-bold"><%= gettext("See current story") %></span>
          </div>
        </div>
      </div>
      <div id="extended-story" class="bg-gray-900 w-full py-3 px-6 text-black shadow-lg rounded-md">
        <div
          class="block w-full h-full cursor-pointer"
          phx-click={toggle_story()}
          phx-target={@myself}
        >
          <div id="story-pane" class="float-right mt-2">
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

          <p class="text-sm text-gray-400 my-1"><%= gettext("Current story") %></p>
          <p class="text-white text-xl font-semibold mb-2"><%= @story.title %></p>
          <%= if @story.multiple do %>
            <p class="text-gray-400 text-sm mb-4"><%= gettext("Select one or multiple options") %></p>
          <% else %>
            <p class="text-gray-400 text-sm mb-4"><%= gettext("Select one option") %></p>
          <% end %>
        </div>
        <div>
          <div class="flex flex-col space-y-3 overflow-y-auto max-h-[500px]">
            <%= if (length @story.story_opts) > 0 do %>
              <%= for {opt, idx} <- Enum.with_index(@story.story_opts) do %>
                <%= if (length @current_story_vote) > 0 do %>
                  <button class="bg-gray-500 px-3 py-2 rounded-lg flex justify-between items-center relative text-white">
                    <div
                      style={"width: #{if @show_results, do: opt.percentage, else: 0}%;"}
                      class={"bg-gradient-to-r from-primary-500 to-secondary-500 h-full absolute left-0 transition-all rounded-l-lg #{if opt.percentage == "100", do: "rounded-r-lg"}"}
                    >
                    </div>
                    <div class="flex space-x-3 items-center z-10 text-left">
                      <%= if (length Enum.filter(@current_story_vote, fn(vote) -> vote.story_opt_id == opt.id end)) > 0 do %>
                        <%= if @story.multiple do %>
                          <span class="h-5 w-5 mt-0.5 point-select bg-white"></span>
                        <% else %>
                          <span class="h-5 w-5 mt-0.5 rounded-full point-select bg-white"></span>
                        <% end %>
                      <% else %>
                        <%= if @story.multiple do %>
                          <span class="h-5 w-5 mt-0.5 point-select border-2 border-white"></span>
                        <% else %>
                          <span class="h-5 w-5 mt-0.5 rounded-full point-select border-2 border-white">
                          </span>
                        <% end %>
                      <% end %>
                      <span class="flex-1 pr-2"><%= opt.content %></span>
                    </div>
                    <span :if={@show_results} class="text-sm z-10">
                      <%= opt.percentage %>% (<%= opt.vote_count %>)
                    </span>
                  </button>
                <% else %>
                  <button
                    id={"story-opt-#{idx}"}
                    phx-click="select-story-opt"
                    phx-value-opt={idx}
                    class="bg-gray-500 px-3 py-2 flex justify-between items-center rounded-lg relative text-white"
                  >
                    <div
                      style={"width: #{if @show_results, do: opt.percentage, else: 0}%;"}
                      class={"bg-gradient-to-r from-primary-500 to-secondary-500 h-full absolute left-0 transition-all rounded-l-lg #{if opt.percentage == "100", do: "rounded-r-lg"}"}
                    >
                    </div>
                    <div class="flex space-x-3 items-center z-10 text-left">
                      <%= if Enum.member?(@selected_story_opt, "#{idx}") do %>
                        <%= if @story.multiple do %>
                          <span class="h-5 w-5 mt-0.5 point-select bg-white"></span>
                        <% else %>
                          <span class="h-5 w-5 mt-0.5 rounded-full point-select bg-white"></span>
                        <% end %>
                      <% else %>
                        <%= if @story.multiple do %>
                          <span class="h-5 w-5 mt-0.5 point-select border-2 border-white"></span>
                        <% else %>
                          <span class="h-5 w-5 mt-0.5 rounded-full point-select border-2 border-white">
                          </span>
                        <% end %>
                      <% end %>
                      <span class="flex-1 pr-2"><%= opt.content %></span>
                    </div>
                    <span :if={@show_results} class="text-sm z-10">
                      <%= opt.percentage %>% (<%= opt.vote_count %>)
                    </span>
                  </button>
                <% end %>
              <% end %>
            <% end %>
          </div>

          <%= if (length @selected_story_opt) == 0 || (length @current_story_vote) > 0 do %>
            <button class="px-3 py-2 text-white font-medium bg-gray-500 rounded-md mt-3 mb-4 cursor-default">
              <%= gettext("Vote") %>
            </button>
          <% else %>
            <button
              phx-click="svote"
              phx-disable-with="..."
              class="px-3 py-2 text-white font-medium bg-primary-400 hover:bg-primary-500 rounded-md mt-3 mb-4"
            >
              <%= gettext("Vote") %>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def toggle_story(js \\ %JS{}) do
    js
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#collapsed-story",
      time: 50
    )
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#extended-story"
    )
  end
end
