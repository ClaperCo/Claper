defmodule ClaperWeb.EventLive.EventCardComponent do
  use ClaperWeb, :live_component

  alias Claper.Events.Event
  alias Claper.Presentations

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:is_leader, fn -> false end)
      |> assign_new(:view_mode, fn -> "grid" end)
      |> assign(:thumbnail_url, get_thumbnail_url(assigns.event))

    case assigns.view_mode do
      "grid" -> render_grid_card(assigns)
      "mobile" -> render_mobile_card(assigns)
      _ -> render_list_card(assigns)
    end
  end

  defp get_thumbnail_url(event) do
    Presentations.get_first_slide_url(event.presentation_file)
  end

  defp dom_id(component_id, suffix) do
    "#{component_id}-#{suffix}"
  end

  defp toggle_join_menu(id) do
    JS.toggle(
      to: "##{dom_id(id, "join-menu")}",
      in: {"transition ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
      out: {"transition ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"},
      time: 100
    )
    |> JS.toggle_class("rotate-180", to: "##{dom_id(id, "join-arrow")}")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"},
      to: "##{dom_id(id, "join-button")}"
    )
  end

  defp close_join_menu(id) do
    JS.hide(
      to: "##{dom_id(id, "join-menu")}",
      transition: "transition ease-in duration-75",
      time: 75
    )
    |> JS.remove_class("rotate-180", to: "##{dom_id(id, "join-arrow")}")
    |> JS.set_attribute({"aria-expanded", "false"}, to: "##{dom_id(id, "join-button")}")
  end

  defp render_grid_card(assigns) do
    ~H"""
    <div
      id={dom_id(@id, "card")}
      class="group relative bg-white border border-gray-200 rounded-2xl overflow-hidden hover:shadow-lg transition-shadow duration-200 h-96"
    >
      <!-- Full-height Thumbnail Area -->
      <div class="absolute inset-0">
        <%= if @thumbnail_url do %>
          <img src={@thumbnail_url} alt={@event.name} class="w-full h-full object-cover" />
        <% else %>
          <div class="w-full h-full bg-gray-100 flex items-center justify-center">
            <img src="/images/logo.svg" class="h-12 opacity-30" alt="Claper" />
          </div>
        <% end %>
        <!-- Processing Overlay -->
        <div
          :if={@event.presentation_file.status == "progress"}
          class="absolute inset-0 bg-white/80 backdrop-blur-sm flex flex-col items-center justify-center gap-3"
        >
          <img src="/images/logo.svg" class="h-12 animate-pulse" alt="Loading" />
          <span class="text-sm font-medium text-gray-600">{gettext("Processing...")}</span>
        </div>
      </div>
      
    <!-- Status Badge -->
      <div class="absolute top-4 left-4 z-10">
        <%= if !Event.unscheduled?(@event) && Event.started?(@event) && !Event.finished?(@event) do %>
          <div class="px-3 py-1 text-xs font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-red-600 text-white flex items-center gap-1">
            <span class="h-1.5 w-1.5 bg-white rounded-full animate-pulse"></span>
            {gettext("Live")}
          </div>
        <% end %>
        <%= if !Event.started?(@event) && !Event.finished?(@event) do %>
          <div class="px-3 py-1 text-xs font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-primary text-primary-content">
            {gettext("Incoming")}
          </div>
        <% end %>
        <%= if Event.unscheduled?(@event) && !Event.finished?(@event) do %>
          <div class="px-3 py-1 text-xs font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-gray-100 text-gray-800">
            {gettext("Unscheduled")}
          </div>
        <% end %>
        <%= if Event.finished?(@event) do %>
          <div class="px-3 py-1 text-xs font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-gray-100 text-gray-800">
            {gettext("Finished")}
          </div>
        <% end %>
      </div>
      
    <!-- LTI Badge -->
      <div :if={@event.lti_resource} class="absolute top-4 right-4 z-10">
        <span class="badge badge-neutral gap-1">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            class="h-3 w-3"
          >
            <path
              fill-rule="evenodd"
              d="M9.664 1.319a.75.75 0 0 1 .672 0 41.059 41.059 0 0 1 8.198 5.424.75.75 0 0 1-.254 1.285 31.372 31.372 0 0 0-7.86 3.83.75.75 0 0 1-.84 0 31.508 31.508 0 0 0-2.08-1.287V9.394c0-.244.116-.463.302-.592a35.504 35.504 0 0 1 3.305-2.033.75.75 0 0 0-.714-1.319 37 37 0 0 0-3.446 2.12A2.216 2.216 0 0 0 6 9.393v.38a31.293 31.293 0 0 0-4.28-1.746.75.75 0 0 1-.254-1.285 41.059 41.059 0 0 1 8.198-5.424ZM6 11.459a29.848 29.848 0 0 0-2.455-1.158 41.029 41.029 0 0 0-.39 3.114.75.75 0 0 0 .419.74c.528.256 1.046.53 1.554.82-.21.324-.455.63-.739.914a.75.75 0 1 0 1.06 1.06c.37-.369.69-.77.96-1.193a26.61 26.61 0 0 1 3.095 2.348.75.75 0 0 0 .992 0 26.547 26.547 0 0 1 5.93-3.95.75.75 0 0 0 .42-.739 41.053 41.053 0 0 0-.39-3.114 29.925 29.925 0 0 0-5.199 2.801 2.25 2.25 0 0 1-2.514 0c-.41-.275-.826-.541-1.25-.797a6.985 6.985 0 0 1-1.084 3.45 26.503 26.503 0 0 0-1.281-.78A5.487 5.487 0 0 0 6 12v-.54Z"
              clip-rule="evenodd"
            />
          </svg>
          LTI
        </span>
      </div>
      
    <!-- Sliding Bottom Panel -->
      <div class="absolute bottom-0 left-0 right-0 bg-white transition-transform duration-300 ease-out z-20 translate-y-14 group-hover:translate-y-0 group-focus-within:translate-y-0">
        <!-- Card Body (Title, Code, Menu) -->
        <div class="p-2 border-t border-gray-200">
          <div class="flex items-start justify-between gap-4">
            <div class="flex-1 min-w-0">
              <h3 class="font-bold text-gray-800 truncate">
                {@event.name}
              </h3>
              <p class="text-gray-500 text-base uppercase">
                # {@event.code}
              </p>
            </div>
            
    <!-- 3-dot Menu -->
            <div :if={not @is_leader} class="relative shrink-0">
              <button
                phx-click-away={JS.hide(to: "##{dom_id(@id, "dropdown-menu")}")}
                phx-click={JS.toggle(to: "##{dom_id(@id, "dropdown-menu")}")}
                phx-target={@myself}
                class="p-1 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-6 w-6"
                  fill="currentColor"
                  viewBox="0 0 24 24"
                >
                  <circle cx="12" cy="5" r="2" />
                  <circle cx="12" cy="12" r="2" />
                  <circle cx="12" cy="19" r="2" />
                </svg>
              </button>
              <div
                id={dom_id(@id, "dropdown-menu")}
                phx-hook="Dropdown"
                class="hidden absolute right-0 bottom-full mb-2 w-52 dropdown-content menu bg-base-100 rounded-box shadow-lg z-30"
              >
                {render_dropdown_menu(assigns)}
              </div>
            </div>
          </div>
        </div>
        
    <!-- Action Buttons (revealed on hover) -->
        <div
          :if={@event.presentation_file.status == "done" && !Event.finished?(@event)}
          class="px-2 pb-2 flex gap-2"
        >
          <!-- Join Button with Dropdown -->
          <div class="relative flex-1">
            <button
              id={dom_id(@id, "join-button")}
              type="button"
              aria-expanded="false"
              aria-controls={dom_id(@id, "join-menu")}
              phx-click={toggle_join_menu(@id)}
              class="btn btn-primary w-full"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M5.22 14.78a.75.75 0 001.06 0l7.22-7.22v5.69a.75.75 0 001.5 0v-7.5a.75.75 0 00-.75-.75h-7.5a.75.75 0 000 1.5h5.69l-7.22 7.22a.75.75 0 000 1.06z"
                  clip-rule="evenodd"
                />
              </svg>
              {gettext("Join")}
              <svg
                id={dom_id(@id, "join-arrow")}
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 transition-transform"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0 1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22 9.28a.75.75 0 0 1 0-1.06Z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
            <!-- Dropdown Menu -->
            <div
              id={dom_id(@id, "join-menu")}
              phx-click-away={close_join_menu(@id)}
              class="hidden absolute bottom-full left-0 right-0 mb-2 bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden"
            >
              <a
                href={~p"/e/#{@event.code}/manage"}
                class="flex items-center gap-3 px-4 py-3 text-gray-700 hover:bg-gray-50 transition"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  class="w-5 h-5"
                >
                  <path
                    fill-rule="evenodd"
                    d="M2.25 2.25a.75.75 0 0 0 0 1.5H3v10.5a3 3 0 0 0 3 3h1.21l-1.172 3.513a.75.75 0 0 0 1.424.474l.329-.987h8.418l.33.987a.75.75 0 0 0 1.422-.474l-1.17-3.513H18a3 3 0 0 0 3-3V3.75h.75a.75.75 0 0 0 0-1.5H2.25Zm6.04 16.5.5-1.5h6.42l.5 1.5H8.29Zm7.46-12a.75.75 0 0 0-1.5 0v6a.75.75 0 0 0 1.5 0v-6Zm-3 2.25a.75.75 0 0 0-1.5 0v3.75a.75.75 0 0 0 1.5 0V9Zm-3 2.25a.75.75 0 0 0-1.5 0v1.5a.75.75 0 0 0 1.5 0v-1.5Z"
                    clip-rule="evenodd"
                  />
                </svg>
                <span class="font-medium">{gettext("Event Manager")}</span>
              </a>
              <a
                href={~p"/e/#{@event.code}"}
                class="flex items-center gap-3 px-4 py-3 text-gray-700 hover:bg-gray-50 transition border-t border-gray-100"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  class="w-5 h-5"
                >
                  <path
                    fill-rule="evenodd"
                    d="M8.25 6.75a3.75 3.75 0 1 1 7.5 0 3.75 3.75 0 0 1-7.5 0ZM15.75 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM2.25 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM6.31 15.117A6.745 6.745 0 0 1 12 12a6.745 6.745 0 0 1 6.709 7.498.75.75 0 0 1-.372.568A12.696 12.696 0 0 1 12 21.75c-2.305 0-4.47-.612-6.337-1.684a.75.75 0 0 1-.372-.568 6.787 6.787 0 0 1 1.019-4.38Z"
                    clip-rule="evenodd"
                  />
                  <path d="M5.082 14.254a8.287 8.287 0 0 0-1.308 5.135 9.687 9.687 0 0 1-1.764-.44l-.115-.04a.563.563 0 0 1-.373-.487l-.01-.121a3.75 3.75 0 0 1 3.57-4.047ZM20.226 19.389a8.287 8.287 0 0 0-1.308-5.135 3.75 3.75 0 0 1 3.57 4.047l-.01.121a.563.563 0 0 1-.373.486l-.115.04c-.567.2-1.156.349-1.764.441Z" />
                </svg>
                <span class="font-medium">{gettext("Attendees Room")}</span>
              </a>
            </div>
          </div>
          <!-- End Event Button -->
          <.link
            :if={Event.started?(@event) && not @is_leader}
            data-confirm={
              gettext("Are you sure you want to terminate this event? This action cannot be undone.")
            }
            phx-value-id={@event.uuid}
            phx-click="terminate"
            class="btn btn-outline flex-1"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06 10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22Z" />
            </svg>
            {gettext("End Event")}
          </.link>
        </div>
        
    <!-- Error Status -->
        <div :if={@event.presentation_file.status == "fail"} class="px-2 pb-2">
          <span class="text-sm text-supporting-red-500">
            {gettext("Error when processing the file")}
          </span>
        </div>
        
    <!-- Finished Event Actions -->
        <div :if={Event.finished?(@event)} class="px-2 pb-2">
          <a href={~p"/events/#{@event.uuid}/stats"} class="btn btn-primary w-full">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path d="M2 10a8 8 0 018-8v8h8a8 8 0 11-16 0z" />
              <path d="M12 2.252A8.014 8.014 0 0117.748 8H12V2.252z" />
            </svg>
            {gettext("View report")}
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp render_list_card(assigns) do
    ~H"""
    <div class="w-full" id={dom_id(@id, "card")}>
      <div class="bg-white rounded-2xl border border-gray-200 hover:shadow-lg transition-shadow duration-200">
        <div class="p-4 flex items-center gap-4">
          <!-- Thumbnail -->
          <div class="shrink-0 w-24 h-16 rounded-lg overflow-hidden border border-gray-200 relative">
            <%= if @thumbnail_url do %>
              <img src={@thumbnail_url} alt={@event.name} class="w-full h-full object-cover" />
            <% else %>
              <div class="w-full h-full bg-gray-100 flex items-center justify-center">
                <img src="/images/logo.svg" class="h-6 opacity-30" alt="Claper" />
              </div>
            <% end %>
            <!-- Processing Overlay -->
            <div
              :if={@event.presentation_file.status == "progress"}
              class="absolute inset-0 bg-white/80 backdrop-blur-sm flex items-center justify-center"
            >
              <img src="/images/logo.svg" class="h-6 animate-pulse" alt="Loading" />
            </div>
          </div>
          
    <!-- Event Info -->
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <h3 class="text-lg font-bold text-gray-800 truncate">
                {@event.name}
              </h3>
              <!-- Status Badge -->
              <%= if !Event.unscheduled?(@event) && Event.started?(@event) && !Event.finished?(@event) do %>
                <div class="px-3 py-1 text-xs font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-red-600 text-white flex items-center gap-1">
                  <span class="h-1.5 w-1.5 bg-white rounded-full animate-pulse"></span>
                  {gettext("Live")}
                </div>
              <% end %>
              <%= if !Event.started?(@event) && !Event.finished?(@event) do %>
                <div class="px-3 py-1 text-xs font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-primary text-primary-content">
                  {gettext("Incoming")}
                </div>
              <% end %>
              <%= if Event.unscheduled?(@event) && !Event.finished?(@event) do %>
                <div class="px-3 py-1 text-xs font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-gray-100 text-gray-800">
                  {gettext("Unscheduled")}
                </div>
              <% end %>
              <%= if Event.finished?(@event) do %>
                <div class="px-3 py-1 text-xs font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-gray-100 text-gray-800">
                  {gettext("Finished")}
                </div>
              <% end %>
              <span :if={@event.lti_resource} class="badge badge-neutral badge-sm gap-1">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  class="h-3 w-3"
                >
                  <path
                    fill-rule="evenodd"
                    d="M9.664 1.319a.75.75 0 0 1 .672 0 41.059 41.059 0 0 1 8.198 5.424.75.75 0 0 1-.254 1.285 31.372 31.372 0 0 0-7.86 3.83.75.75 0 0 1-.84 0 31.508 31.508 0 0 0-2.08-1.287V9.394c0-.244.116-.463.302-.592a35.504 35.504 0 0 1 3.305-2.033.75.75 0 0 0-.714-1.319 37 37 0 0 0-3.446 2.12A2.216 2.216 0 0 0 6 9.393v.38a31.293 31.293 0 0 0-4.28-1.746.75.75 0 0 1-.254-1.285 41.059 41.059 0 0 1 8.198-5.424ZM6 11.459a29.848 29.848 0 0 0-2.455-1.158 41.029 41.029 0 0 0-.39 3.114.75.75 0 0 0 .419.74c.528.256 1.046.53 1.554.82-.21.324-.455.63-.739.914a.75.75 0 1 0 1.06 1.06c.37-.369.69-.77.96-1.193a26.61 26.61 0 0 1 3.095 2.348.75.75 0 0 0 .992 0 26.547 26.547 0 0 1 5.93-3.95.75.75 0 0 0 .42-.739 41.053 41.053 0 0 0-.39-3.114 29.925 29.925 0 0 0-5.199 2.801 2.25 2.25 0 0 1-2.514 0c-.41-.275-.826-.541-1.25-.797a6.985 6.985 0 0 1-1.084 3.45 26.503 26.503 0 0 0-1.281-.78A5.487 5.487 0 0 0 6 12v-.54Z"
                    clip-rule="evenodd"
                  />
                </svg>
                LTI
              </span>
            </div>
            <div class="flex items-center gap-4 text-sm text-gray-500">
              <span class="font-medium uppercase"># {@event.code}</span>
              <span
                :if={!Event.finished?(@event) && !Event.started?(@event)}
                id={dom_id(@id, "event-date")}
              >
                {gettext("Starting on")}
                <time
                  id={dom_id(@id, "local-start")}
                  phx-hook="LocalDate"
                  datetime={"#{NaiveDateTime.to_iso8601(@event.started_at)}Z"}
                  data-utc={NaiveDateTime.to_iso8601(@event.started_at)}
                  data-format="lll"
                >
                  {@event.started_at} UTC
                </time>
              </span>
              <span :if={Event.finished?(@event)} id={dom_id(@id, "event-date")}>
                {gettext("Finished on")}
                <time
                  id={dom_id(@id, "local-end")}
                  phx-hook="LocalDate"
                  datetime={"#{NaiveDateTime.to_iso8601(@event.expired_at)}Z"}
                  data-utc={NaiveDateTime.to_iso8601(@event.expired_at)}
                  data-format="lll"
                >
                  {@event.expired_at} UTC
                </time>
              </span>
            </div>
          </div>
          
    <!-- Actions -->
          <div class="flex items-center gap-2 ml-auto">
            <%= if @event.presentation_file.status == "done" && !Event.finished?(@event) do %>
              <!-- Join Button with Dropdown -->
              <div class="relative">
                <button
                  id={dom_id(@id, "join-button")}
                  type="button"
                  aria-expanded="false"
                  aria-controls={dom_id(@id, "join-menu")}
                  phx-click={toggle_join_menu(@id)}
                  class="btn btn-primary"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M5.22 14.78a.75.75 0 001.06 0l7.22-7.22v5.69a.75.75 0 001.5 0v-7.5a.75.75 0 00-.75-.75h-7.5a.75.75 0 000 1.5h5.69l-7.22 7.22a.75.75 0 000 1.06z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  {gettext("Join")}
                  <svg
                    id={dom_id(@id, "join-arrow")}
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4 transition-transform"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0 1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22 9.28a.75.75 0 0 1 0-1.06Z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </button>
                <!-- Dropdown Menu -->
                <div
                  id={dom_id(@id, "join-menu")}
                  phx-click-away={close_join_menu(@id)}
                  class="hidden absolute top-full right-0 mt-2 bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden z-30"
                >
                  <a
                    href={~p"/e/#{@event.code}/manage"}
                    class="flex items-center gap-3 px-4 py-3 text-gray-700 hover:bg-gray-50 transition whitespace-nowrap"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 24 24"
                      fill="currentColor"
                      class="w-5 h-5"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M2.25 2.25a.75.75 0 0 0 0 1.5H3v10.5a3 3 0 0 0 3 3h1.21l-1.172 3.513a.75.75 0 0 0 1.424.474l.329-.987h8.418l.33.987a.75.75 0 0 0 1.422-.474l-1.17-3.513H18a3 3 0 0 0 3-3V3.75h.75a.75.75 0 0 0 0-1.5H2.25Zm6.04 16.5.5-1.5h6.42l.5 1.5H8.29Zm7.46-12a.75.75 0 0 0-1.5 0v6a.75.75 0 0 0 1.5 0v-6Zm-3 2.25a.75.75 0 0 0-1.5 0v3.75a.75.75 0 0 0 1.5 0V9Zm-3 2.25a.75.75 0 0 0-1.5 0v1.5a.75.75 0 0 0 1.5 0v-1.5Z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    <span class="font-medium">{gettext("Event Manager")}</span>
                  </a>
                  <a
                    href={~p"/e/#{@event.code}"}
                    class="flex items-center gap-3 px-4 py-3 text-gray-700 hover:bg-gray-50 transition border-t border-gray-100 whitespace-nowrap"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 24 24"
                      fill="currentColor"
                      class="w-5 h-5"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M8.25 6.75a3.75 3.75 0 1 1 7.5 0 3.75 3.75 0 0 1-7.5 0ZM15.75 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM2.25 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM6.31 15.117A6.745 6.745 0 0 1 12 12a6.745 6.745 0 0 1 6.709 7.498.75.75 0 0 1-.372.568A12.696 12.696 0 0 1 12 21.75c-2.305 0-4.47-.612-6.337-1.684a.75.75 0 0 1-.372-.568 6.787 6.787 0 0 1 1.019-4.38Z"
                        clip-rule="evenodd"
                      />
                      <path d="M5.082 14.254a8.287 8.287 0 0 0-1.308 5.135 9.687 9.687 0 0 1-1.764-.44l-.115-.04a.563.563 0 0 1-.373-.487l-.01-.121a3.75 3.75 0 0 1 3.57-4.047ZM20.226 19.389a8.287 8.287 0 0 0-1.308-5.135 3.75 3.75 0 0 1 3.57 4.047l-.01.121a.563.563 0 0 1-.373.486l-.115.04c-.567.2-1.156.349-1.764.441Z" />
                    </svg>
                    <span class="font-medium">{gettext("Attendees Room")}</span>
                  </a>
                </div>
              </div>
              <!-- End Event Button -->
              <.link
                :if={Event.started?(@event) && not @is_leader}
                data-confirm={
                  gettext(
                    "Are you sure you want to terminate this event? This action cannot be undone."
                  )
                }
                phx-value-id={@event.uuid}
                phx-click="terminate"
                class="btn btn-outline"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06 10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22Z" />
                </svg>
                {gettext("End Event")}
              </.link>
            <% end %>

            <%= if @event.presentation_file.status == "progress" do %>
              <div class="flex items-center gap-2">
                <img src="/images/logo.svg" class="h-5 animate-pulse" alt="Loading" />
                <span class="text-sm text-gray-500">{gettext("Processing...")}</span>
              </div>
            <% end %>

            <%= if @event.presentation_file.status == "fail" do %>
              <span class="text-sm text-supporting-red-500">{gettext("Error")}</span>
            <% end %>

            <%= if Event.finished?(@event) do %>
              <a href={~p"/events/#{@event.uuid}/stats"} class="btn btn-primary">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path d="M2 10a8 8 0 018-8v8h8a8 8 0 11-16 0z" />
                  <path d="M12 2.252A8.014 8.014 0 0117.748 8H12V2.252z" />
                </svg>
                {gettext("View report")}
              </a>
            <% end %>
            
    <!-- 3-dot Menu -->
            <div :if={not @is_leader} class="relative">
              <button
                phx-click-away={JS.hide(to: "##{dom_id(@id, "dropdown-menu")}")}
                phx-click={JS.toggle(to: "##{dom_id(@id, "dropdown-menu")}")}
                phx-target={@myself}
                class="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  fill="currentColor"
                  viewBox="0 0 24 24"
                >
                  <circle cx="12" cy="5" r="2" />
                  <circle cx="12" cy="12" r="2" />
                  <circle cx="12" cy="19" r="2" />
                </svg>
              </button>
              <div
                id={dom_id(@id, "dropdown-menu")}
                phx-hook="Dropdown"
                class="hidden absolute right-0 top-10 w-52 dropdown-content menu bg-base-100 rounded-box shadow-lg z-30"
              >
                {render_dropdown_menu(assigns)}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_mobile_card(assigns) do
    ~H"""
    <div class="w-full" id={dom_id(@id, "card")}>
      <div class="bg-white rounded-3xl border border-gray-200 p-2">
        <div class="flex flex-col gap-2">
          <!-- Top Row: Thumbnail + Info + Menu -->
          <div class="flex gap-3 items-start">
            <!-- Thumbnail -->
            <div class="shrink-0 w-28 h-24 rounded-2xl overflow-hidden bg-gray-100 relative">
              <%= if @thumbnail_url do %>
                <img src={@thumbnail_url} alt={@event.name} class="w-full h-full object-cover" />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <img src="/images/logo.svg" class="h-8 opacity-30" alt="Claper" />
                </div>
              <% end %>
              <!-- Processing Overlay -->
              <div
                :if={@event.presentation_file.status == "progress"}
                class="absolute inset-0 bg-white/80 backdrop-blur-sm flex items-center justify-center"
              >
                <img src="/images/logo.svg" class="h-8 animate-pulse" alt="Loading" />
              </div>
            </div>
            
    <!-- Event Info -->
            <div class="flex-1 min-w-0 py-1">
              <h3 class="font-semibold text-gray-800 text-lg leading-tight truncate">
                {@event.name}
              </h3>
              <div class="flex items-center gap-2 mt-1">
                <span class="text-xs text-gray-500"># {@event.code}</span>
                <!-- Status Badge -->
                <%= if !Event.unscheduled?(@event) && Event.started?(@event) && !Event.finished?(@event) do %>
                  <span class="px-2 py-0.5 text-[10px] font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-red-600 text-white flex items-center gap-1">
                    <span class="h-1.5 w-1.5 bg-white rounded-full animate-pulse"></span>
                    {gettext("Live")}
                  </span>
                <% end %>
                <%= if !Event.started?(@event) && !Event.finished?(@event) do %>
                  <span class="px-2 py-0.5 text-[10px] font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-primary text-primary-content">
                    {gettext("Incoming")}
                  </span>
                <% end %>
                <%= if Event.unscheduled?(@event) && !Event.finished?(@event) do %>
                  <span class="px-2 py-0.5 text-[10px] font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-gray-100 text-gray-800">
                    {gettext("Unscheduled")}
                  </span>
                <% end %>
                <%= if Event.finished?(@event) do %>
                  <span class="px-2 py-0.5 text-[10px] font-medium rounded-tr-lg rounded-br-lg rounded-bl-lg bg-gray-100 text-gray-600">
                    {gettext("Finished")}
                  </span>
                <% end %>
              </div>
            </div>
            
    <!-- 3-dot Menu -->
            <div :if={not @is_leader} class="relative shrink-0">
              <button
                phx-click-away={JS.hide(to: "##{dom_id(@id, "dropdown-menu")}")}
                phx-click={JS.toggle(to: "##{dom_id(@id, "dropdown-menu")}")}
                phx-target={@myself}
                class="p-1.5 text-gray-400 hover:text-gray-600"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  fill="currentColor"
                  viewBox="0 0 24 24"
                >
                  <circle cx="12" cy="5" r="2" />
                  <circle cx="12" cy="12" r="2" />
                  <circle cx="12" cy="19" r="2" />
                </svg>
              </button>
              <div
                id={dom_id(@id, "dropdown-menu")}
                phx-hook="Dropdown"
                class="hidden absolute right-0 top-8 w-52 dropdown-content menu bg-base-100 rounded-box shadow-lg z-30"
              >
                {render_dropdown_menu(assigns)}
              </div>
            </div>
          </div>
          
    <!-- Bottom Row: Action Buttons -->
          <div class="flex gap-2">
            <%= if @event.presentation_file.status == "done" && !Event.finished?(@event) do %>
              <!-- Join Button with Dropdown -->
              <div class="relative flex-1">
                <button
                  id={dom_id(@id, "join-button")}
                  type="button"
                  aria-expanded="false"
                  aria-controls={dom_id(@id, "join-menu")}
                  phx-click={toggle_join_menu(@id)}
                  class="btn btn-primary w-full"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M5.22 14.78a.75.75 0 001.06 0l7.22-7.22v5.69a.75.75 0 001.5 0v-7.5a.75.75 0 00-.75-.75h-7.5a.75.75 0 000 1.5h5.69l-7.22 7.22a.75.75 0 000 1.06z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  {gettext("Join")}
                  <svg
                    id={dom_id(@id, "join-arrow")}
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4 transition-transform"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0 1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22 9.28a.75.75 0 0 1 0-1.06Z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </button>
                <!-- Dropdown Menu -->
                <div
                  id={dom_id(@id, "join-menu")}
                  phx-click-away={close_join_menu(@id)}
                  class="hidden absolute bottom-full left-0 right-0 mb-2 bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden z-30"
                >
                  <a
                    href={~p"/e/#{@event.code}/manage"}
                    class="flex items-center gap-3 px-4 py-3 text-gray-700 hover:bg-gray-50 transition"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 24 24"
                      fill="currentColor"
                      class="w-5 h-5"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M2.25 2.25a.75.75 0 0 0 0 1.5H3v10.5a3 3 0 0 0 3 3h1.21l-1.172 3.513a.75.75 0 0 0 1.424.474l.329-.987h8.418l.33.987a.75.75 0 0 0 1.422-.474l-1.17-3.513H18a3 3 0 0 0 3-3V3.75h.75a.75.75 0 0 0 0-1.5H2.25Zm6.04 16.5.5-1.5h6.42l.5 1.5H8.29Zm7.46-12a.75.75 0 0 0-1.5 0v6a.75.75 0 0 0 1.5 0v-6Zm-3 2.25a.75.75 0 0 0-1.5 0v3.75a.75.75 0 0 0 1.5 0V9Zm-3 2.25a.75.75 0 0 0-1.5 0v1.5a.75.75 0 0 0 1.5 0v-1.5Z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    <span class="font-medium">{gettext("Event Manager")}</span>
                  </a>
                  <a
                    href={~p"/e/#{@event.code}"}
                    class="flex items-center gap-3 px-4 py-3 text-gray-700 hover:bg-gray-50 transition border-t border-gray-100"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 24 24"
                      fill="currentColor"
                      class="w-5 h-5"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M8.25 6.75a3.75 3.75 0 1 1 7.5 0 3.75 3.75 0 0 1-7.5 0ZM15.75 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM2.25 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM6.31 15.117A6.745 6.745 0 0 1 12 12a6.745 6.745 0 0 1 6.709 7.498.75.75 0 0 1-.372.568A12.696 12.696 0 0 1 12 21.75c-2.305 0-4.47-.612-6.337-1.684a.75.75 0 0 1-.372-.568 6.787 6.787 0 0 1 1.019-4.38Z"
                        clip-rule="evenodd"
                      />
                      <path d="M5.082 14.254a8.287 8.287 0 0 0-1.308 5.135 9.687 9.687 0 0 1-1.764-.44l-.115-.04a.563.563 0 0 1-.373-.487l-.01-.121a3.75 3.75 0 0 1 3.57-4.047ZM20.226 19.389a8.287 8.287 0 0 0-1.308-5.135 3.75 3.75 0 0 1 3.57 4.047l-.01.121a.563.563 0 0 1-.373.486l-.115.04c-.567.2-1.156.349-1.764.441Z" />
                    </svg>
                    <span class="font-medium">{gettext("Attendees Room")}</span>
                  </a>
                </div>
              </div>
              <!-- End Event Button -->
              <.link
                :if={Event.started?(@event) && not @is_leader}
                data-confirm={
                  gettext(
                    "Are you sure you want to terminate this event? This action cannot be undone."
                  )
                }
                phx-value-id={@event.uuid}
                phx-click="terminate"
                class="btn btn-outline flex-1"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06 10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22Z" />
                </svg>
                {gettext("End Event")}
              </.link>
            <% end %>

            <%= if @event.presentation_file.status == "progress" do %>
              <div class="flex items-center gap-2 px-3 py-2">
                <img src="/images/logo.svg" class="h-5 animate-pulse" alt="Loading" />
                <span class="text-sm text-gray-500">{gettext("Processing...")}</span>
              </div>
            <% end %>

            <%= if @event.presentation_file.status == "fail" do %>
              <span class="text-sm text-supporting-red-500 px-3 py-2">{gettext("Error")}</span>
            <% end %>

            <%= if Event.finished?(@event) do %>
              <a href={~p"/events/#{@event.uuid}/stats"} class="btn btn-primary w-full">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path d="M2 10a8 8 0 018-8v8h8a8 8 0 11-16 0z" />
                  <path d="M12 2.252A8.014 8.014 0 0117.748 8H12V2.252z" />
                </svg>
                {gettext("View report")}
              </a>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_dropdown_menu(assigns) do
    ~H"""
    <ul class="w-full">
      <%= if !Event.finished?(@event) && not @is_leader do %>
        <li>
          <.link
            patch={~p"/events/#{@event.uuid}/edit"}
            class="flex items-center gap-3 w-full px-3 py-2 hover:bg-gray-50"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path d="m5.433 13.917 1.262-3.155A4 4 0 0 1 7.58 9.42l6.92-6.918a2.121 2.121 0 0 1 3 3l-6.92 6.918c-.383.383-.84.685-1.343.886l-3.154 1.262a.5.5 0 0 1-.65-.65Z" />
              <path d="M3.5 5.75c0-.69.56-1.25 1.25-1.25H10A.75.75 0 0 0 10 3H4.75A2.75 2.75 0 0 0 2 5.75v9.5A2.75 2.75 0 0 0 4.75 18h9.5A2.75 2.75 0 0 0 17 15.25V10a.75.75 0 0 0-1.5 0v5.25c0 .69-.56 1.25-1.25 1.25h-9.5c-.69 0-1.25-.56-1.25-1.25v-9.5Z" />
            </svg>
            {gettext("Edit")}
          </.link>
        </li>
        <li>
          <button
            phx-value-id={@event.uuid}
            phx-click="duplicate"
            class="flex items-center gap-3 w-full px-3 py-2 hover:bg-gray-50"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path d="M7 3.5A1.5 1.5 0 0 1 8.5 2h3.879a1.5 1.5 0 0 1 1.06.44l3.122 3.12A1.5 1.5 0 0 1 17 6.622V12.5a1.5 1.5 0 0 1-1.5 1.5h-1v-3.379a3 3 0 0 0-.879-2.121L10.5 5.379A3 3 0 0 0 8.379 4.5H7v-1Z" />
              <path d="M4.5 6A1.5 1.5 0 0 0 3 7.5v9A1.5 1.5 0 0 0 4.5 18h7a1.5 1.5 0 0 0 1.5-1.5v-5.879a1.5 1.5 0 0 0-.44-1.06L9.44 6.439A1.5 1.5 0 0 0 8.378 6H4.5Z" />
            </svg>
            {gettext("Duplicate")}
          </button>
        </li>
      <% end %>

      <%= if Event.finished?(@event) && not @is_leader do %>
        <li>
          <button
            phx-value-id={@event.uuid}
            phx-click="duplicate"
            class="flex items-center gap-3 w-full px-3 py-2 hover:bg-gray-50"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path d="M7 3.5A1.5 1.5 0 0 1 8.5 2h3.879a1.5 1.5 0 0 1 1.06.44l3.122 3.12A1.5 1.5 0 0 1 17 6.622V12.5a1.5 1.5 0 0 1-1.5 1.5h-1v-3.379a3 3 0 0 0-.879-2.121L10.5 5.379A3 3 0 0 0 8.379 4.5H7v-1Z" />
              <path d="M4.5 6A1.5 1.5 0 0 0 3 7.5v9A1.5 1.5 0 0 0 4.5 18h7a1.5 1.5 0 0 0 1.5-1.5v-5.879a1.5 1.5 0 0 0-.44-1.06L9.44 6.439A1.5 1.5 0 0 0 8.378 6H4.5Z" />
            </svg>
            {gettext("Duplicate")}
          </button>
        </li>
        <li>
          <.link
            phx-click="delete"
            phx-value-id={@event.uuid}
            data-confirm={
              gettext(
                "This will delete all data related to your event, this cannot be undone. Confirm ?"
              )
            }
            class="flex items-center gap-3 w-full px-3 py-2 hover:bg-gray-50 text-error"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 16 16"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path
                fill-rule="evenodd"
                d="M5 3.25V4H2.75a.75.75 0 0 0 0 1.5h.3l.815 8.15A1.5 1.5 0 0 0 5.357 15h5.285a1.5 1.5 0 0 0 1.493-1.35l.815-8.15h.3a.75.75 0 0 0 0-1.5H11v-.75A2.25 2.25 0 0 0 8.75 1h-1.5A2.25 2.25 0 0 0 5 3.25Zm2.25-.75a.75.75 0 0 0-.75.75V4h3v-.75a.75.75 0 0 0-.75-.75h-1.5ZM6.05 6a.75.75 0 0 1 .787.713l.275 5.5a.75.75 0 0 1-1.498.075l-.275-5.5A.75.75 0 0 1 6.05 6Zm3.9 0a.75.75 0 0 1 .712.787l-.275 5.5a.75.75 0 0 1-1.498-.075l.275-5.5a.75.75 0 0 1 .786-.711Z"
                clip-rule="evenodd"
              />
            </svg>
            {gettext("Delete")}
          </.link>
        </li>
      <% end %>
    </ul>
    """
  end

  def handle_event("open", _params, socket) do
    {:noreply, socket |> assign(:dropdown, true)}
  end
end
