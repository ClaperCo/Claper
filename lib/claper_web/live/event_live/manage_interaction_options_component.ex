defmodule ClaperWeb.EventLive.ManageInteractionOptionsComponent do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: ClaperWeb.Gettext

  def render(assigns) do
    assigns = assigns |> assign_new(:show_shortcut, fn -> true end)

    ~H"""
    <div class="flex flex-col gap-2 border border-gray-200 rounded-2xl p-2 bg-white shadow-lg">
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
          class="icon icon-tabler icons-tabler-outline icon-tabler-pointer-cog shrink-0 text-[#140553]"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M15.774 13.218l-.996 -.996l3.113 -2.09a1.2 1.2 0 0 0 -.309 -2.228l-13.582 -3.904l3.904 13.563a1.2 1.2 0 0 0 2.228 .308l2.09 -3.093l.343 .343" />
          <path d="M17.001 19a2 2 0 1 0 4 0a2 2 0 1 0 -4 0" />
          <path d="M19.001 15.5v1.5" />
          <path d="M19.001 21v1.5" />
          <path d="M22.032 17.25l-1.299 .75" />
          <path d="M17.27 20l-1.3 .75" />
          <path d="M15.97 17.25l1.3 .75" />
          <path d="M20.733 20l1.3 .75" />
        </svg>
        <span class="font-bold text-sm text-[#140553]">
          {gettext("Current Interaction Settings")}
        </span>
      </div>

      <div class="space-y-2 px-1">
        <%= case @current_interaction do %>
          <% %Claper.Polls.Poll{} -> %>
            <.toggle_row
              label={
                if @state.poll_visible,
                  do: gettext("Hide results on presentation"),
                  else: gettext("Show results on presentation")
              }
              checked={@state.poll_visible}
              key={:poll_visible}
              shortcut={if @create == nil, do: "Z", else: nil}
              show_shortcut={@show_shortcut}
            >
              <:icon>
                <svg
                  :if={@state.poll_visible}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-5 w-5"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4h1m4 0h13" /><path d="M4 4v10a2 2 0 0 0 2 2h10m3.42 -.592c.359 -.362 .58 -.859 .58 -1.408v-10" /><path d="M12 16v4" /><path d="M9 20h6" /><path d="M8 12l2 -2m4 0l2 -2" /><path d="M3 3l18 18" />
                </svg>
                <svg
                  :if={!@state.poll_visible}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-5 w-5"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4l18 0" /><path d="M4 4v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-10" /><path d="M12 16l0 4" /><path d="M9 20l6 0" /><path d="M8 12l3 -3l2 2l3 -3" />
                </svg>
              </:icon>
            </.toggle_row>
          <% %Claper.Quizzes.Quiz{} -> %>
            <div class="space-y-2">
              <.toggle_row
                label={
                  if @current_interaction.show_results,
                    do: gettext("Hide results on presentation"),
                    else: gettext("Show results on presentation")
                }
                checked={@current_interaction.show_results}
                key={:quiz_show_results}
                shortcut={if @create == nil, do: "Z", else: nil}
                show_shortcut={@show_shortcut}
              >
                <:icon>
                  <svg
                    :if={@current_interaction.show_results}
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4h1m4 0h13" /><path d="M4 4v10a2 2 0 0 0 2 2h10m3.42 -.592c.359 -.362 .58 -.859 .58 -1.408v-10" /><path d="M12 16v4" /><path d="M9 20h6" /><path d="M8 12l2 -2m4 0l2 -2" /><path d="M3 3l18 18" />
                  </svg>
                  <svg
                    :if={!@current_interaction.show_results}
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4l18 0" /><path d="M4 4v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-10" /><path d="M12 16l0 4" /><path d="M9 20l6 0" /><path d="M8 12l3 -3l2 2l3 -3" />
                  </svg>
                </:icon>
              </.toggle_row>

              <.action_row
                label={gettext("Review questions")}
                key={:review_quiz_questions}
                disabled={!@current_interaction.show_results}
              >
                <:icon>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="w-5 h-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 13a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v6a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M15 9a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M9 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v14a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M4 20h14" />
                  </svg>
                </:icon>
              </.action_row>

              <div class="grid grid-cols-2 gap-2">
                <.action_row
                  label={gettext("Previous")}
                  key={:prev_quiz_question}
                  disabled={!@current_interaction.show_results}
                  compact
                >
                  <:icon>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      class="w-5 h-5"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M11.78 5.22a.75.75 0 0 1 0 1.06L8.06 10l3.72 3.72a.75.75 0 1 1-1.06 1.06l-4.25-4.25a.75.75 0 0 1 0-1.06l4.25-4.25a.75.75 0 0 1 1.06 0Z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </:icon>
                </.action_row>

                <.action_row
                  label={gettext("Next")}
                  key={:next_quiz_question}
                  disabled={!@current_interaction.show_results}
                  compact
                  reverse
                >
                  <:icon>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      class="w-5 h-5"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M8.22 5.22a.75.75 0 0 1 1.06 0l4.25 4.25a.75.75 0 0 1 0 1.06l-4.25 4.25a.75.75 0 0 1-1.06-1.06L11.94 10 8.22 6.28a.75.75 0 0 1 0-1.06Z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </:icon>
                </.action_row>
              </div>
            </div>
          <% %Claper.WordClouds.WordCloud{} -> %>
            <div class="space-y-2">
              <.toggle_row
                label={
                  if @current_interaction.show_results,
                    do: gettext("Hide the word cloud from attendees"),
                    else: gettext("Show the word cloud to attendees")
                }
                checked={@current_interaction.show_results}
                key={:word_cloud_show_results}
                shortcut={if @create == nil, do: "Z", else: nil}
                show_shortcut={@show_shortcut}
              >
                <:icon>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M6 5a2 2 0 0 1 2 -2h8a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-8a2 2 0 0 1 -2 -2v-14z" /><path d="M11 4h2" /><path d="M12 17v.01" />
                  </svg>
                </:icon>
              </.toggle_row>

              <.word_cloud_preview word_cloud={@current_interaction} words={@word_cloud_words} />
            </div>
          <% nil -> %>
            <p class="text-gray-400 italic mt-1.5 text-sm">{gettext("No interaction enabled")}</p>
          <% _ -> %>
            <p class="text-gray-400 italic mt-1.5 text-sm">
              {gettext("No settings available for this interaction")}
            </p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :checked, :boolean, required: true
  attr :key, :atom, required: true
  attr :shortcut, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :show_shortcut, :boolean, default: true
  slot :icon, required: true

  defp toggle_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-2 rounded-full pl-2 pr-3 py-2 overflow-hidden transition-colors",
      if(@disabled, do: "opacity-50"),
      if(@checked,
        do: "bg-[#f3defa] border-b-2 border-primary",
        else: "bg-white border border-gray-200"
      )
    ]}>
      <div class={[
        "flex items-center justify-center w-8 h-8 rounded-full shrink-0",
        if(@checked, do: "bg-white text-primary-500", else: "bg-gray-100 text-secondary-500")
      ]}>
        {render_slot(@icon)}
      </div>
      <span class={["flex-1 text-xs text-gray-700", if(@checked, do: "font-semibold")]}>
        {@label}
      </span>
      <div class="flex items-center gap-x-2 shrink-0">
        <kbd :if={@show_shortcut && @shortcut} class="kbd kbd-sm">
          {@shortcut}
        </kbd>
        <button
          phx-click={ClaperWeb.Component.Input.checked(@checked, @key)}
          disabled={@disabled}
          phx-value-key={@key}
          type="button"
          class={"relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none disabled:cursor-not-allowed #{if @checked, do: "bg-primary-500", else: "bg-gray-200"}"}
          role="switch"
          aria-checked={@checked}
          phx-key={@shortcut}
          phx-window-keydown={
            if @shortcut && not @disabled, do: ClaperWeb.Component.Input.checked(@checked, @key)
          }
        >
          <span class={"pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out #{if @checked, do: "translate-x-5", else: "translate-x-0"}"}>
          </span>
        </button>
      </div>
    </div>
    """
  end

  attr :word_cloud, Claper.WordClouds.WordCloud, required: true
  attr :words, :list, required: true

  defp word_cloud_preview(assigns) do
    ~H"""
    <div class="rounded-2xl border border-gray-200 p-3">
      <p class="mb-2 text-xs font-semibold text-gray-500">{gettext("Words")}</p>
      <p :if={@words == []} class="text-gray-400 italic text-sm">{gettext("No words yet")}</p>
      <div :if={@words != []} class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <button
          :for={word <- @words}
          type="button"
          phx-click="hide-word"
          phx-value-id={@word_cloud.id}
          phx-value-key={word.key}
          title={gettext("Hide this word")}
          class="font-bold text-primary-600 hover:text-gray-400 hover:line-through"
          style={"font-size: #{ClaperWeb.Helpers.word_size(word.percentage, 12, 16)}px"}
        >
          {word.text}<sup class="ml-0.5 text-[10px] font-normal text-gray-400">{word.count}</sup>
        </button>
      </div>

      <div :if={@word_cloud.hidden_words != []} class="mt-3">
        <p class="mb-1 text-xs font-semibold text-gray-500">{gettext("Hidden words")}</p>
        <div class="flex flex-wrap gap-1">
          <button
            :for={key <- @word_cloud.hidden_words}
            type="button"
            phx-click="unhide-word"
            phx-value-id={@word_cloud.id}
            phx-value-key={key}
            title={gettext("Show this word again")}
            class="rounded-full border border-gray-200 px-2 py-0.5 text-xs text-gray-500 line-through hover:no-underline hover:bg-primary-50"
          >
            {key}
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :key, :atom, required: true
  attr :disabled, :boolean, default: false
  attr :compact, :boolean, default: false
  attr :reverse, :boolean, default: false
  slot :icon, required: true

  defp action_row(assigns) do
    ~H"""
    <button
      phx-click={ClaperWeb.Component.Input.checked(false, @key)}
      phx-value-key={@key}
      type="button"
      disabled={@disabled}
      class={[
        "w-full flex items-center rounded-full border border-gray-200 bg-white text-left transition-colors",
        if(@compact, do: "px-1 py-2", else: "gap-3 pl-2 pr-3 py-2"),
        if(@reverse, do: "flex-row-reverse"),
        if(@disabled, do: "opacity-50 cursor-not-allowed", else: "hover:bg-primary-50")
      ]}
    >
      <div class="flex items-center justify-center w-8 h-8 rounded-full shrink-0 bg-gray-100 text-secondary-500">
        {render_slot(@icon)}
      </div>
      <span class={[
        "text-xs text-gray-700",
        if(@compact, do: "flex-1 text-center font-medium", else: "flex-1")
      ]}>
        {@label}
      </span>
    </button>
    """
  end
end
