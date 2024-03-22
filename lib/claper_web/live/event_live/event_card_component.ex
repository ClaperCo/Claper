defmodule ClaperWeb.EventLive.EventCardComponent do
  use ClaperWeb, :live_component

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
              <%= if NaiveDateTime.compare(@current_time, @event.started_at) == :gt and NaiveDateTime.compare(@current_time, @event.expired_at) == :lt do %>
                <p class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-yellow-100 text-yellow-800">
                  <%= gettext("In progress") %>
                </p>
              <% end %>
              <%= if NaiveDateTime.compare(@current_time, @event.started_at) == :lt do %>
                <p class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                  <%= gettext("Incoming") %>
                </p>
              <% end %>
              <%= if NaiveDateTime.compare(@current_time, @event.expired_at) == :gt do %>
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
              <img src="/images/icons/calendar-clear-outline.svg" class="h-5 w-5" />
              <%= if NaiveDateTime.compare(@current_time, @event.started_at) == :gt and NaiveDateTime.compare(@current_time, @event.expired_at) == :lt do %>
                <p>
                  <%= gettext("Finish on") %>
                  <span x-text={"moment.utc('#{@event.expired_at}').local().format('lll')"}></span>
                </p>
              <% end %>
              <%= if NaiveDateTime.compare(@current_time, @event.started_at) == :lt do %>
                <p>
                  <%= gettext("Starting on") %>
                  <span x-text={"moment.utc('#{@event.started_at}').local().format('lll')"}></span>
                </p>
              <% end %>
              <%= if NaiveDateTime.compare(@current_time, @event.expired_at) == :gt do %>
                <p>
                  <%= gettext("Finished on") %>
                  <span x-text={"moment.utc('#{@event.expired_at}').local().format('lll')"}></span>
                </p>
              <% end %>
            </div>
          </div>

          <%= if @event.presentation_file.status == "fail" && @event.presentation_file.hash do %>
            <p class="text-sm font-normal text-supporting-red-500 text-left pt-2">
              <%= gettext("Error when processing the new file") %>
            </p>
          <% end %>

          <%= if NaiveDateTime.compare(@current_time, @event.expired_at) == :lt do %>
            <%= if @event.presentation_file.status == "done" || (@event.presentation_file.status == "fail" && @event.presentation_file.hash) do %>
              <div class="mt-2 flex flex-col space-y-2 sm:space-y-0 justify-between sm:flex-row items-center">
                <div
                  id={"event-infos-0-#{@event.uuid}"}
                  class="text-sm w-full space-y-2 sm:w-auto font-medium text-gray-700 sm:flex sm:justify-center sm:space-x-1 sm:space-y-0 sm:items-center"
                  phx-update="ignore"
                >
                  <a
                    data-phx-link="patch"
                    data-phx-link-state="push"
                    href={Routes.event_manage_path(@socket, :show, @event.code)}
                    class="flex w-full lg:w-auto px-6 text-white py-2 justify-center rounded-md tracking-wide font-bold focus:outline-none focus:shadow-outline hover:bg-primary-600 bg-primary-500 space-x-2"
                  >
                    <img src="/images/icons/easel.svg" class="h-5" />
                    <span><%= gettext("Present/Customize") %></span>
                  </a>
                  <a
                    target="_blank"
                    href={Routes.event_show_path(@socket, :show, @event.code)}
                    class="flex w-full lg:w-auto px-6 text-primary-500 py-2 justify-center rounded-md tracking-wide focus:outline-none focus:shadow-outline bg-white items-center space-x-2"
                  >
                    <img src="/images/icons/eye.svg" class="h-5" />
                    <span><%= gettext("Join") %></span>
                  </a>
                </div>
                <div>
                  <%= if not @is_leader do %>
                    <a
                      data-phx-link="patch"
                      data-phx-link-state="push"
                      href={Routes.event_index_path(@socket, :edit, @event.uuid)}
                      class="flex w-full lg:w-auto rounded-md tracking-wide focus:outline-none focus:shadow-outline text-primary-500 text-sm items-center"
                    >
                      <span><%= gettext("Edit") %></span>
                    </a>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if @event.presentation_file.status == "fail" && is_nil(@event.presentation_file.hash) do %>
              <div class="mt-2 flex flex-col space-y-2 sm:space-y-0 justify-between sm:flex-row items-center">
                <span class="text-sm text-supporting-red-500">
                  <%= gettext("Error when processing the file") %>
                </span>
                <div>
                  <%= if not @is_leader do %>
                    <a
                      data-phx-link="patch"
                      data-phx-link-state="push"
                      href={Routes.event_index_path(@socket, :edit, @event.uuid)}
                      class="flex w-full lg:w-auto rounded-md tracking-wide focus:outline-none focus:shadow-outline text-primary-500 text-sm items-center"
                    >
                      <span><%= gettext("Edit") %></span>
                    </a>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if @event.presentation_file.status == "progress" do %>
              <div class="flex space-x-1 items-center">
                <img src="/images/loading.gif" class="h-8" />
                <span class="text-sm text-gray-500"><%= gettext("Processing your file...") %></span>
              </div>
            <% end %>
          <% end %>

          <%= if NaiveDateTime.compare(@current_time, @event.expired_at) == :gt do %>
            <div class="mt-2 flex flex-col space-y-2 sm:space-y-0 justify-between sm:flex-row items-center">
              <div
                id={"event-infos-1-#{@event.uuid}"}
                class="text-sm w-full space-y-2 sm:w-auto font-medium text-gray-700 sm:flex sm:justify-center sm:space-x-1 sm:space-y-0 sm:items-center"
                phx-update="ignore"
              >
                <a
                  href={Routes.stat_index_path(@socket, :index, @event.uuid)}
                  class="flex w-full lg:w-auto px-6 text-white py-2 justify-center rounded-md tracking-wide font-bold focus:outline-none focus:shadow-outline hover:bg-primary-600 bg-primary-500 space-x-2"
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
                  <span><%= gettext("Report") %></span>
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
          <% end %>
        </div>
      </div>
    </li>
    """
  end
end
