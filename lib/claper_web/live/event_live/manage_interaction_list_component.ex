defmodule ClaperWeb.EventLive.ManageInteractionListComponent do
  use ClaperWeb, :live_component

  @per_page 6
  @max_per_page 20
  @fixed_content_height 200
  @interaction_row_height 64

  def update(assigns, socket) do
    page = Map.get(socket.assigns, :page, 0)
    per_page = Map.get(socket.assigns, :per_page, @per_page)
    total = length(assigns.interactions)
    max_page = max_page(total, per_page)
    page = min(page, max_page)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(page: page, per_page: per_page)}
  end

  def handle_event("prev-page", _, socket) do
    {:noreply, assign(socket, page: max(0, socket.assigns.page - 1))}
  end

  def handle_event("next-page", _, socket) do
    max_page = max_page(length(socket.assigns.interactions), socket.assigns.per_page)
    {:noreply, assign(socket, page: min(max_page, socket.assigns.page + 1))}
  end

  def handle_event("interaction-list-resized", %{"height" => height}, socket)
      when is_integer(height) do
    per_page =
      height
      |> Kernel.-(@fixed_content_height)
      |> div(@interaction_row_height)
      |> max(@per_page)
      |> min(@max_per_page)

    first_interaction = socket.assigns.page * socket.assigns.per_page

    page =
      min(
        div(first_interaction, per_page),
        max_page(length(socket.assigns.interactions), per_page)
      )

    {:noreply, assign(socket, page: page, per_page: per_page)}
  end

  defp paginated_interactions(interactions, page, per_page) do
    interactions
    |> Enum.drop(page * per_page)
    |> Enum.take(per_page)
  end

  defp max_page(total, per_page), do: max(0, ceil(total / per_page) - 1)

  def render(assigns) do
    assigns =
      assign(assigns,
        paginated: paginated_interactions(assigns.interactions, assigns.page, assigns.per_page),
        total_pages: max(1, ceil(length(assigns.interactions) / assigns.per_page))
      )

    ~H"""
    <div
      id="interaction-drag-list"
      phx-hook="InteractionDrag"
      phx-target={@myself}
      class="relative flex flex-col gap-2 border border-gray-200 rounded-2xl p-2 lg:flex-1 lg:min-h-0 lg:overflow-y-auto"
    >
      <div class="flex items-center gap-2">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="icon icon-tabler icons-tabler-outline icon-tabler-north-star shrink-0 text-[#140553]"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M3 12h18" />
          <path d="M12 21v-18" />
          <path d="M7.5 7.5l9 9" />
          <path d="M7.5 16.5l9 -9" />
        </svg>
        <span class="font-bold text-sm text-[#140553]">{gettext("Interactions")}</span>
      </div>

      <div class="grid grid-cols-4 gap-1">
        <.action_button patch={~p"/e/#{@event_code}/manage/add/poll"} label={gettext("Poll")}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5"
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
        </.action_button>
        <.action_button patch={~p"/e/#{@event_code}/manage/add/form"} label={gettext("Form")}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
            />
          </svg>
        </.action_button>
        <.action_button patch={~p"/e/#{@event_code}/manage/add/quiz"} label={gettext("Quiz")}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 5.25h.008v.008H12v-.008Z"
            />
          </svg>
        </.action_button>

        <div class="static" x-data="{ open: false }" @click.outside="open = false">
          <button
            @click="open = !open"
            class="flex flex-col items-center justify-center gap-0.5 py-2 rounded-xl text-gray-600 transition-colors hover:bg-primary-50 hover:text-primary-600 w-full"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 text-primary-500"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 6.75a.75.75 0 110-1.5.75.75 0 010 1.5zM12 12.75a.75.75 0 110-1.5.75.75 0 010 1.5zM12 18.75a.75.75 0 110-1.5.75.75 0 010 1.5z"
              />
            </svg>
            <span class="font-bold text-xs leading-normal">{gettext("More")}</span>
          </button>

          <div
            x-show="open"
            x-transition:enter="transition ease-out duration-150"
            x-transition:enter-start="opacity-0 scale-95"
            x-transition:enter-end="opacity-100 scale-100"
            x-transition:leave="transition ease-in duration-100"
            x-transition:leave-start="opacity-100 scale-100"
            x-transition:leave-end="opacity-0 scale-95"
            class="absolute left-0 right-0 mt-1 bg-white border border-gray-100 rounded-2xl p-2 shadow-lg z-50"
            x-cloak
          >
            <.popup_item
              patch={~p"/e/#{@event_code}/manage/add/poll"}
              title={gettext("Poll")}
              description={gettext("Add a poll to gauge your audience's opinion.")}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
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
            </.popup_item>
            <.popup_item
              patch={~p"/e/#{@event_code}/manage/add/form"}
              title={gettext("Form")}
              description={gettext("Create a form to collect feedback from your audience.")}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
                />
              </svg>
            </.popup_item>
            <.popup_item
              patch={~p"/e/#{@event_code}/manage/add/embed"}
              title={gettext("Web Content")}
              description={gettext("Embed external web content into your presentation.")}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M14.25 9.75L16.5 12l-2.25 2.25m-4.5 0L7.5 12l2.25-2.25M6 20.25h12A2.25 2.25 0 0020.25 18V6A2.25 2.25 0 0018 3.75H6A2.25 2.25 0 003.75 6v12A2.25 2.25 0 006 20.25z"
                />
              </svg>
            </.popup_item>
            <.popup_item
              patch={~p"/e/#{@event_code}/manage/add/quiz"}
              title={gettext("Quiz")}
              description={gettext("Test your audience's knowledge with a quiz.")}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 5.25h.008v.008H12v-.008Z"
                />
              </svg>
            </.popup_item>
            <.popup_item
              :if={@transcription_globally_enabled}
              patch={transcription_patch(@event_code, @transcription_config)}
              disabled={transcription_persisted?(@transcription_config)}
              badge={gettext("Global")}
              title={gettext("Transcription")}
              description={
                if transcription_persisted?(@transcription_config),
                  do: gettext("Already added to this presentation."),
                  else: gettext("Live transcribe presenter audio for your audience.")
              }
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18.75a6 6 0 0 0 6-6v-1.5m-6 7.5a6 6 0 0 1-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 0 1-3-3V4.5a3 3 0 1 1 6 0v8.25a3 3 0 0 1-3 3Z"
                />
              </svg>
            </.popup_item>
          </div>
        </div>
      </div>

      <div
        :if={@transcription_globally_enabled and transcription_persisted?(@transcription_config)}
        class={[
          "flex items-center gap-2 overflow-hidden pl-2 pr-3 py-2 rounded-xl w-full",
          if(@transcription_config.enabled,
            do: "bg-gray-100 border-b-2 border-accent",
            else: "bg-white border border-gray-200"
          )
        ]}
      >
        <div class={[
          "flex items-center justify-center rounded-full w-[42px] h-[41px] shrink-0",
          if(@transcription_config.enabled, do: "bg-white", else: "bg-gray-100")
        ]}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5 text-gray-700"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 18.75a6 6 0 0 0 6-6v-1.5m-6 7.5a6 6 0 0 1-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 0 1-3-3V4.5a3 3 0 1 1 6 0v8.25a3 3 0 0 1-3 3Z"
            />
          </svg>
        </div>

        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <p class="font-bold text-sm text-gray-800 leading-snug truncate">
              {gettext("Transcription")}
            </p>
            <span class="badge badge-sm badge-soft badge-primary">{gettext("Global")}</span>
          </div>
          <p class="text-xs text-gray-500 leading-tight truncate">
            {transcription_subtitle(@transcription_config)}
          </p>
        </div>

        <.link
          patch={~p"/e/#{@event_code}/manage/edit/transcription/#{@transcription_config.id}"}
          class="flex items-center justify-center rounded-full w-[42px] h-[41px] shrink-0 border border-[#140553] text-[#140553]"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="20"
            height="20"
            viewBox="0 0 20 20"
            fill="none"
          >
            <path
              d="M3.33301 17.4998H16.6663M4.72134 10.989C4.36602 11.3451 4.16643 11.8276 4.16634 12.3306V14.9998H6.85217C7.35551 14.9998 7.83801 14.7998 8.19384 14.4431L16.1105 6.52229C16.4657 6.16612 16.6652 5.68364 16.6652 5.18063C16.6652 4.67761 16.4657 4.19513 16.1105 3.83896L15.3288 3.05563C15.1526 2.87925 14.9432 2.73935 14.7129 2.64393C14.4825 2.54851 14.2355 2.49943 13.9862 2.49951C13.7368 2.49959 13.4899 2.54882 13.2596 2.64438C13.0292 2.73995 12.82 2.87998 12.6438 3.05646L4.72134 10.989Z"
              stroke="#140553"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </.link>

        <input
          type="checkbox"
          class="toggle toggle-sm shrink-0 bg-gray-200 border-gray-300 [--tglbg:white] checked:bg-white checked:border-accent checked:[--tglbg:var(--color-accent)]"
          checked={@transcription_config.enabled}
          phx-click={
            if(@transcription_config.enabled,
              do: "transcription-set-inactive",
              else: "transcription-set-active"
            )
          }
          phx-value-id={@transcription_config.id}
        />
      </div>

      <div
        :if={length(@interactions) == 0}
        class="flex flex-col items-center justify-center text-gray-400 py-8"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="h-12 w-12 mb-3"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M4 12h6l-6 8h6" /><path d="M14 4h6l-6 8h6" />
        </svg>
        <p class="text-sm text-center">
          {gettext("No interactions on this slide")}
        </p>
      </div>

      <%= for interaction <- @paginated do %>
        <div
          draggable="true"
          data-interaction-id={interaction.id}
          data-interaction-type={type_key(interaction)}
          data-interaction-position={interaction.position}
          class={[
            "flex items-center gap-2 overflow-hidden pl-2 pr-3 py-2 rounded-xl w-full cursor-grab active:cursor-grabbing",
            if(interaction.enabled,
              do: "bg-gray-100 border-b-2 border-accent",
              else: "bg-white border border-gray-200"
            )
          ]}
        >
          <div class={[
            "flex items-center justify-center rounded-full w-[42px] h-[41px] shrink-0",
            if(interaction.enabled, do: "bg-white", else: "bg-gray-100")
          ]}>
            <%= case interaction do %>
              <% %Claper.Polls.Poll{} -> %>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5 text-gray-700"
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
              <% %Claper.Forms.Form{} -> %>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5 text-gray-700"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
                  />
                </svg>
              <% %Claper.Embeds.Embed{} -> %>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                  stroke="currentColor"
                  class="h-5 w-5 text-gray-700"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M14.25 9.75L16.5 12l-2.25 2.25m-4.5 0L7.5 12l2.25-2.25M6 20.25h12A2.25 2.25 0 0020.25 18V6A2.25 2.25 0 0018 3.75H6A2.25 2.25 0 003.75 6v12A2.25 2.25 0 006 20.25z"
                  />
                </svg>
              <% %Claper.Quizzes.Quiz{} -> %>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                  stroke="currentColor"
                  class="h-5 w-5 text-gray-700"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
                  />
                </svg>
              <% _ -> %>
            <% end %>
          </div>

          <div class="flex-1 min-w-0">
            <p class="font-bold text-sm text-gray-800 leading-snug truncate">
              {interaction.title}
            </p>
            <p class="text-xs text-gray-500 leading-tight truncate">
              {type_label(interaction)}
            </p>
          </div>

          <.link
            patch={edit_path(@event_code, interaction)}
            draggable="false"
            class="flex items-center justify-center rounded-full w-[42px] h-[41px] shrink-0 border border-[#140553] text-[#140553]"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="20"
              height="20"
              viewBox="0 0 20 20"
              fill="none"
            >
              <path
                d="M3.33301 17.4998H16.6663M4.72134 10.989C4.36602 11.3451 4.16643 11.8276 4.16634 12.3306V14.9998H6.85217C7.35551 14.9998 7.83801 14.7998 8.19384 14.4431L16.1105 6.52229C16.4657 6.16612 16.6652 5.68364 16.6652 5.18063C16.6652 4.67761 16.4657 4.19513 16.1105 3.83896L15.3288 3.05563C15.1526 2.87925 14.9432 2.73935 14.7129 2.64393C14.4825 2.54851 14.2355 2.49943 13.9862 2.49951C13.7368 2.49959 13.4899 2.54882 13.2596 2.64438C13.0292 2.73995 12.82 2.87998 12.6438 3.05646L4.72134 10.989Z"
                stroke="#140553"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </.link>

          <input
            type="checkbox"
            class="toggle toggle-sm shrink-0 bg-gray-200 border-gray-300 [--tglbg:white] checked:bg-white checked:border-accent checked:[--tglbg:var(--color-accent)]"
            checked={interaction.enabled}
            phx-click={toggle_event(interaction)}
            phx-value-id={interaction.id}
          />
        </div>
      <% end %>

      <div :if={@total_pages > 1} class="flex items-center justify-between pt-1">
        <button
          phx-click="prev-page"
          phx-target={@myself}
          disabled={@page == 0}
          class="p-1 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 disabled:opacity-30 disabled:cursor-not-allowed"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <span class="text-xs text-gray-400">
          {@page + 1} / {@total_pages}
        </span>
        <button
          phx-click="next-page"
          phx-target={@myself}
          disabled={@page >= @total_pages - 1}
          class="p-1 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 disabled:opacity-30 disabled:cursor-not-allowed"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  defp type_key(%Claper.Polls.Poll{}), do: "poll"
  defp type_key(%Claper.Forms.Form{}), do: "form"
  defp type_key(%Claper.Embeds.Embed{}), do: "embed"
  defp type_key(%Claper.Quizzes.Quiz{}), do: "quiz"
  defp type_key(_), do: nil

  defp type_label(%Claper.Polls.Poll{}), do: gettext("Poll")
  defp type_label(%Claper.Forms.Form{}), do: gettext("Form")
  defp type_label(%Claper.Embeds.Embed{}), do: gettext("Web content")
  defp type_label(%Claper.Quizzes.Quiz{}), do: gettext("Quiz")
  defp type_label(_), do: ""

  defp edit_path(event_code, %Claper.Polls.Poll{id: id}),
    do: ~p"/e/#{event_code}/manage/edit/poll/#{id}"

  defp edit_path(event_code, %Claper.Forms.Form{id: id}),
    do: ~p"/e/#{event_code}/manage/edit/form/#{id}"

  defp edit_path(event_code, %Claper.Embeds.Embed{id: id}),
    do: ~p"/e/#{event_code}/manage/edit/embed/#{id}"

  defp edit_path(event_code, %Claper.Quizzes.Quiz{id: id}),
    do: ~p"/e/#{event_code}/manage/edit/quiz/#{id}"

  defp edit_path(event_code, _), do: ~p"/e/#{event_code}/manage"

  defp toggle_event(%Claper.Polls.Poll{enabled: true}), do: "poll-set-inactive"
  defp toggle_event(%Claper.Polls.Poll{enabled: false}), do: "poll-set-active"
  defp toggle_event(%Claper.Forms.Form{enabled: true}), do: "form-set-inactive"
  defp toggle_event(%Claper.Forms.Form{enabled: false}), do: "form-set-active"
  defp toggle_event(%Claper.Embeds.Embed{enabled: true}), do: "embed-set-inactive"
  defp toggle_event(%Claper.Embeds.Embed{enabled: false}), do: "embed-set-active"
  defp toggle_event(%Claper.Quizzes.Quiz{enabled: true}), do: "quiz-set-inactive"
  defp toggle_event(%Claper.Quizzes.Quiz{enabled: false}), do: "quiz-set-active"
  defp toggle_event(_), do: ""

  defp transcription_patch(event_code, %Claper.Transcriptions.TranscriptionConfig{id: id})
       when not is_nil(id),
       do: ~p"/e/#{event_code}/manage/edit/transcription/#{id}"

  defp transcription_patch(event_code, _),
    do: ~p"/e/#{event_code}/manage/add/transcription"

  defp transcription_subtitle(%Claper.Transcriptions.TranscriptionConfig{enabled: true}),
    do: gettext("Live")

  defp transcription_subtitle(_), do: gettext("Disabled")

  defp transcription_persisted?(%Claper.Transcriptions.TranscriptionConfig{id: id})
       when not is_nil(id),
       do: true

  defp transcription_persisted?(_), do: false

  defp action_button(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class="flex flex-col items-center justify-center gap-0.5 py-2 px-3 rounded-xl text-gray-600 transition-colors hover:bg-primary-50 hover:text-primary-600"
    >
      <div class="text-primary-500">
        {render_slot(@inner_block)}
      </div>
      <span class="font-bold text-xs leading-normal">{@label}</span>
    </.link>
    """
  end

  defp popup_item(assigns) do
    assigns =
      assigns
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:badge, fn -> nil end)

    ~H"""
    <%= if @disabled do %>
      <div
        class="flex items-center gap-3 p-2 rounded-xl opacity-50 cursor-not-allowed"
        aria-disabled="true"
      >
        <div class="flex items-center justify-center w-9 h-9 rounded-full bg-primary-50 text-primary-500 shrink-0">
          {render_slot(@inner_block)}
        </div>
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <p class="font-bold text-sm text-gray-900 leading-snug">{@title}</p>
            <span :if={@badge} class="badge badge-sm badge-soft badge-primary">{@badge}</span>
          </div>
          <p class="text-xs text-gray-500 leading-tight">{@description}</p>
        </div>
      </div>
    <% else %>
      <.link
        patch={@patch}
        class="flex items-center gap-3 p-2 rounded-xl transition-colors hover:bg-primary-50"
      >
        <div class="flex items-center justify-center w-9 h-9 rounded-full bg-primary-50 text-primary-500 shrink-0">
          {render_slot(@inner_block)}
        </div>
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <p class="font-bold text-sm text-gray-900 leading-snug">{@title}</p>
            <span :if={@badge} class="badge badge-sm badge-soft badge-primary">{@badge}</span>
          </div>
          <p class="text-xs text-gray-500 leading-tight">{@description}</p>
        </div>
      </.link>
    <% end %>
    """
  end
end
