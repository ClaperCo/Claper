defmodule ClaperWeb.EventLive.EventCardComponent do
  use ClaperWeb, :live_component

  alias Claper.Events.Event

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:is_leader, fn -> false end)

    ~H"""
    <li class="w-full my-4" id={"event-#{@event.uuid}"}>
      <div class="block bg-white rounded-2xl shadow-base">
        <div class="px-4 py-4 sm:px-6">
          <div class="flex items-center justify-between">
            <p class="text-lg font-medium text-primary-600 truncate">
              <%= @event.name %>
            </p>
            <div class="ml-2 flex-shrink-0 flex">
              <%= if Event.started?(@event) && !Event.finished?(@event) do %>
                <div class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-500 text-white items-center gap-x-1">
                  <span class="h-2 w-2 bg-white rounded-full animate__animated animate__flash animate__infinite animate__slow_slow">
                  </span>
                  <%= gettext("Live") %>
                </div>
              <% end %>
              <%= if !Event.started?(@event) && !Event.finished?(@event) do %>
                <p class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                  <%= gettext("Incoming") %>
                </p>
              <% end %>
              <%= if Event.finished?(@event) do %>
                <p class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                  <%= gettext("Finished") %>
                </p>
              <% end %>
            </div>
          </div>
          <div class="mt-2 flex flex-col space-y-2 sm:space-y-0 justify-between sm:flex-row items-start">
            <div class="text-sm font-medium uppercase text-gray-700 flex justify-center space-x-1 items-center">
              <img src="/images/icons/hashtag.svg" class="h-5 w-5" />
              <p>
                <%= @event.code %>
              </p>
            </div>
            <div
              id={"event-infos-#{@event.uuid}"}
              class="flex items-center text-sm text-gray-500 space-x-1"
              phx-update="ignore"
            >
              <img
                :if={
                  Event.finished?(@event) ||
                    !Event.started?(@event)
                }
                src="/images/icons/calendar-clear-outline.svg"
                class="h-5 w-5"
              />
              <p :if={!Event.finished?(@event) && !Event.started?(@event)}>
                <%= gettext("Starting on") %>
                <span x-text={"moment.utc('#{@event.started_at}').local().format('lll')"}></span>
              </p>
              <p :if={Event.finished?(@event)}>
                <%= gettext("Finished on") %>
                <span x-text={"moment.utc('#{@event.expired_at}').local().format('lll')"}></span>
              </p>
            </div>
          </div>

          <%= if !Event.finished?(@event) do %>
            <div
              :if={@event.presentation_file.status == "done"}
              class="mt-2 flex flex-col space-y-2 sm:space-y-0 justify-between sm:flex-row items-center"
            >
              <div
                id={"event-infos-#{@event.uuid}"}
                class="text-sm w-full sm:w-auto font-medium text-gray-700 flex justify-center space-x-1 sm:space-y-0 items-center relative"
              >
                <button
                  phx-click-away={JS.hide(to: "#dropdown-#{@event.uuid}")}
                  phx-click={JS.toggle(to: "#dropdown-#{@event.uuid}")}
                  phx-target={@myself}
                  class="flex w-full lg:w-auto pl-3 pr-4 text-white items-center justify-between py-2 rounded-md tracking-wide font-bold focus:outline-none focus:shadow-outline hover:bg-primary-600 bg-primary-500"
                >
                  <span class="mr-2"><%= gettext("Access") %></span>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="2.5"
                    stroke="currentColor"
                    class="w-4 h-4"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="m19.5 8.25-7.5 7.5-7.5-7.5"
                    />
                  </svg>
                </button>
                <div
                  phx-hook="Dropdown"
                  id={"dropdown-#{@event.uuid}"}
                  class="hidden rounded shadow-lg bg-white border px-2 py-1 absolute -left-1 top-9 w-max"
                >
                  <ul>
                    <li>
                      <a
                        data-phx-link="patch"
                        data-phx-link-state="push"
                        class="py-2 px-2 rounded text-gray-600 hover:bg-gray-100 flex items-center gap-x-2"
                        href={~p"/e/#{@event.code}/manage"}
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          fill="currentColor"
                          class="w-6 h-6"
                        >
                          <path
                            fill-rule="evenodd"
                            d="M2.25 2.25a.75.75 0 0 0 0 1.5H3v10.5a3 3 0 0 0 3 3h1.21l-1.172 3.513a.75.75 0 0 0 1.424.474l.329-.987h8.418l.33.987a.75.75 0 0 0 1.422-.474l-1.17-3.513H18a3 3 0 0 0 3-3V3.75h.75a.75.75 0 0 0 0-1.5H2.25Zm6.04 16.5.5-1.5h6.42l.5 1.5H8.29Zm7.46-12a.75.75 0 0 0-1.5 0v6a.75.75 0 0 0 1.5 0v-6Zm-3 2.25a.75.75 0 0 0-1.5 0v3.75a.75.75 0 0 0 1.5 0V9Zm-3 2.25a.75.75 0 0 0-1.5 0v1.5a.75.75 0 0 0 1.5 0v-1.5Z"
                            clip-rule="evenodd"
                          />
                        </svg>
                        <span><%= gettext("Presentation manager") %></span>
                      </a>
                    </li>
                    <li>
                      <a
                        data-phx-link="patch"
                        data-phx-link-state="push"
                        class="py-2 px-2 rounded text-gray-600 hover:bg-gray-100 flex items-center gap-x-2"
                        href={~p"/e/#{@event.code}"}
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          fill="currentColor"
                          class="w-6 h-6"
                        >
                          <path
                            fill-rule="evenodd"
                            d="M8.25 6.75a3.75 3.75 0 1 1 7.5 0 3.75 3.75 0 0 1-7.5 0ZM15.75 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM2.25 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM6.31 15.117A6.745 6.745 0 0 1 12 12a6.745 6.745 0 0 1 6.709 7.498.75.75 0 0 1-.372.568A12.696 12.696 0 0 1 12 21.75c-2.305 0-4.47-.612-6.337-1.684a.75.75 0 0 1-.372-.568 6.787 6.787 0 0 1 1.019-4.38Z"
                            clip-rule="evenodd"
                          />
                          <path d="M5.082 14.254a8.287 8.287 0 0 0-1.308 5.135 9.687 9.687 0 0 1-1.764-.44l-.115-.04a.563.563 0 0 1-.373-.487l-.01-.121a3.75 3.75 0 0 1 3.57-4.047ZM20.226 19.389a8.287 8.287 0 0 0-1.308-5.135 3.75 3.75 0 0 1 3.57 4.047l-.01.121a.563.563 0 0 1-.373.486l-.115.04c-.567.2-1.156.349-1.764.441Z" />
                        </svg>
                        <span><%= gettext("Attendees room") %></span>
                      </a>
                    </li>
                  </ul>
                </div>
                <.link
                  :if={Event.started?(@event) && not @is_leader}
                  data-confirm={
                    gettext(
                      "Are you sure you want to terminate this event? This action cannot be undone."
                    )
                  }
                  phx-value-id={@event.uuid}
                  phx-click="terminate"
                  class="flex w-full lg:w-auto pl-3 pr-4 text-white items-center justify-between py-2 rounded-md tracking-wide font-bold focus:outline-none focus:shadow-outline bg-red-500 hover:bg-red-600 transition"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="2.5"
                    stroke="currentColor"
                    class="w-5 h-5 mr-2"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
                  </svg>
                  <span><%= gettext("Terminate") %></span>
                </.link>
              </div>
              <div>
                <%= if not @is_leader do %>
                  <a
                    data-phx-link="patch"
                    data-phx-link-state="push"
                    href={~p"/events/#{@event.uuid}/edit"}
                    class="flex w-full lg:w-auto rounded-md tracking-wide focus:outline-none focus:shadow-outline text-primary-500 text-sm items-center"
                  >
                    <span><%= gettext("Edit") %></span>
                  </a>
                <% end %>
              </div>
            </div>

            <div
              :if={@event.presentation_file.status == "fail"}
              class="mt-2 flex flex-col space-y-2 sm:space-y-0 justify-between sm:flex-row items-center"
            >
              <span class="text-sm text-supporting-red-500">
                <%= gettext("Error when processing the file") %>
              </span>
              <div>
                <%= if not @is_leader do %>
                  <a
                    data-phx-link="patch"
                    data-phx-link-state="push"
                    href={~p"/events/#{@event.uuid}/edit"}
                    class="flex w-full lg:w-auto rounded-md tracking-wide focus:outline-none focus:shadow-outline text-primary-500 text-sm items-center"
                  >
                    <span><%= gettext("Edit") %></span>
                  </a>
                <% end %>
              </div>
            </div>

            <div
              :if={@event.presentation_file.status == "progress"}
              class="flex space-x-1 items-center"
            >
              <img src="/images/loading.gif" class="h-8" />
              <span class="text-sm text-gray-500"><%= gettext("Processing your file...") %></span>
            </div>
          <% end %>

          <div
            :if={Event.finished?(@event)}
            class="mt-2 flex flex-col space-y-2 sm:space-y-0 justify-between sm:flex-row items-center"
          >
            <div
              id={"event-infos-1-#{@event.uuid}"}
              class="text-sm w-full space-y-2 sm:w-auto font-medium text-gray-700 sm:flex sm:justify-center sm:space-x-1 sm:space-y-0 sm:items-center"
              phx-update="ignore"
            >
              <a
                href={~p"/events/#{@event.uuid}/stats"}
                class="flex w-full lg:w-auto px-3 text-white py-2 justify-center rounded-md tracking-wide font-bold focus:outline-none focus:shadow-outline hover:bg-primary-600 bg-primary-500 space-x-2"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path d="M2 10a8 8 0 018-8v8h8a8 8 0 11-16 0z" />
                  <path d="M12 2.252A8.014 8.014 0 0117.748 8H12V2.252z" />
                </svg>
                <span><%= gettext("View report") %></span>
              </a>
            </div>
            <div>
              <%= if not @is_leader do %>
                <%= link(gettext("Delete"),
                  to: "#",
                  phx_click: "delete",
                  phx_value_id: @event.uuid,
                  data: [
                    confirm:
                      gettext(
                        "This will delete all data related to your event, this cannot be undone. Confirm ?"
                      )
                  ],
                  class:
                    "flex w-full lg:w-auto rounded-md tracking-wide focus:outline-none focus:shadow-outline text-red-500 text-sm items-center"
                ) %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </li>
    """
  end

  def handle_event("open", _params, socket) do
    {:noreply, socket |> assign(:dropdown, true)}
  end
end
