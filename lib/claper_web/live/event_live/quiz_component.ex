defmodule ClaperWeb.EventLive.QuizComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:focus_mode, fn -> false end)
      |> assign(:is_submitted, assigns.current_quiz_responses != [])
      |> assign(
        :current_question,
        check_current_question(assigns)
      )
      |> assign(
        :has_selection,
        assigns.selected_quiz_question_opts != []
      )
      |> assign(
        :response_opt_ids,
        Enum.map(assigns.current_quiz_responses, & &1.quiz_question_opt_id)
      )
      |> assign(
        :response_opt_ids,
        Enum.map(assigns.current_quiz_responses, & &1.quiz_question_opt_id)
      )

    ~H"""
    <div class="font-display">
      <div
        :if={!@focus_mode}
        id="collapsed-quiz"
        class="mx-auto hidden w-max rounded-full bg-gray-900 px-5 py-3 shadow-xl ring-1 ring-white/10"
      >
        <button
          type="button"
          class="block h-full w-full cursor-pointer"
          phx-click={toggle_quiz()}
          phx-target={@myself}
        >
          <div class="flex items-center gap-2 text-white">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="h-5 w-5 text-primary-300"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
              />
            </svg>
            <span class="text-sm font-bold">{gettext("See current quiz")}</span>
          </div>
        </button>
      </div>
      <div
        id="extended-quiz"
        class={[
          "w-full rounded-2xl bg-gray-900 p-4 text-gray-100",
          @focus_mode && "shadow-none ring-0",
          !@focus_mode && "shadow-2xl ring-1 ring-white/10"
        ]}
      >
        <div class="relative pr-8">
          <button
            :if={!@focus_mode}
            id="quiz-pane"
            type="button"
            aria-label={gettext("Close")}
            class="absolute -right-1 -top-1 grid h-8 w-8 place-items-center rounded-full text-gray-400 transition-colors hover:bg-white/10 hover:text-white"
            phx-click={toggle_quiz()}
            phx-target={@myself}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <p class="mb-1 text-xs font-semibold text-gray-400">{gettext("Current quiz")}</p>
          <%= if is_nil(@current_question) do %>
            <p class="mb-2 text-lg font-bold leading-snug text-white">{@quiz.title}</p>
          <% else %>
            <p class="mb-1 text-lg font-bold leading-snug text-white">
              {@current_question.content}
            </p>
            <p class="mb-4 text-sm text-gray-400">
              {@current_quiz_question_idx + 1}/{length(@quiz.quiz_questions)}
            </p>
          <% end %>
        </div>
        <div>
          <div class="flex max-h-[500px] flex-col gap-2 overflow-y-auto">
            <%= if @current_question do %>
              <%= for {opt, _idx} <- Enum.with_index(@current_question.quiz_question_opts) do %>
                <%= if @is_submitted do %>
                  <% selected = Enum.member?(@response_opt_ids, opt.id) %>
                  <div class={[
                    "relative flex items-center justify-between rounded-xl border px-3 py-2 text-sm font-semibold transition-colors",
                    opt.is_correct &&
                      "border-supporting-green-500 bg-supporting-green-900/40 text-supporting-green-200",
                    !opt.is_correct && selected &&
                      "border-supporting-red-400 bg-supporting-red-900/40 text-supporting-red-200",
                    !opt.is_correct && !selected &&
                      "border-gray-700 bg-gray-800 text-gray-300 opacity-60"
                  ]}>
                    <div class="flex min-w-0 items-center gap-3 text-left">
                      <span class={[
                        "grid h-4 w-4 shrink-0 place-items-center rounded border-2",
                        opt.is_correct && "border-supporting-green-500",
                        !opt.is_correct && selected && "border-supporting-red-400",
                        !opt.is_correct && !selected && "border-gray-500"
                      ]}>
                        <span
                          :if={selected}
                          class={[
                            "h-1.5 w-1.5 rounded-sm",
                            opt.is_correct && "bg-supporting-green-500",
                            !opt.is_correct && "bg-supporting-red-400"
                          ]}
                        >
                        </span>
                      </span>
                      <span class="min-w-0 flex-1 pr-2">{opt.content}</span>
                    </div>

                    <span class="shrink-0 text-xs font-bold">
                      {opt.percentage}% ({opt.response_count})
                    </span>
                  </div>
                <% else %>
                  <button
                    phx-click="select-quiz-question-opt"
                    phx-value-opt={opt.id}
                    aria-pressed={
                      to_string(Enum.any?(@selected_quiz_question_opts, &(&1.id == opt.id)))
                    }
                    class={[
                      "relative flex items-center justify-between rounded-xl border px-3 py-2 text-sm font-semibold text-white transition-colors",
                      Enum.any?(@selected_quiz_question_opts, &(&1.id == opt.id)) &&
                        "border-primary-400 bg-primary-900/40",
                      !Enum.any?(@selected_quiz_question_opts, &(&1.id == opt.id)) &&
                        "border-gray-700 bg-gray-800 hover:border-primary-400"
                    ]}
                  >
                    <div class="flex min-w-0 items-center gap-3 text-left">
                      <span class={[
                        "grid h-4 w-4 shrink-0 place-items-center rounded border-2",
                        Enum.any?(@selected_quiz_question_opts, &(&1.id == opt.id)) &&
                          "border-primary-300",
                        !Enum.any?(@selected_quiz_question_opts, &(&1.id == opt.id)) &&
                          "border-gray-500"
                      ]}>
                        <span
                          :if={Enum.any?(@selected_quiz_question_opts, &(&1.id == opt.id))}
                          class="h-1.5 w-1.5 rounded-sm bg-primary-300"
                        >
                        </span>
                      </span>
                      <span class="min-w-0 flex-1 pr-2">{opt.content}</span>
                    </div>
                  </button>
                <% end %>
              <% end %>
            <% else %>
              <div class="mt-4 flex flex-col items-center justify-center text-center font-semibold text-white">
                <%= if @quiz.show_results do %>
                  <p class="text-sm text-gray-400">{gettext("Your score")}</p>
                  <p class="mt-2 text-5xl font-bold">
                    {elem(@quiz_score, 0)}/{elem(@quiz_score, 1)}
                  </p>
                  <button
                    phx-click="show-quiz-results"
                    class="btn-gradient mt-6 w-full rounded-lg px-3 py-2 text-sm font-bold"
                  >
                    {gettext("Show results")}
                  </button>
                <% else %>
                  <p class="text-sm text-gray-400">{gettext("Waiting for results...")}</p>
                  <svg
                    class="mt-4 h-24 w-24 text-white/50"
                    viewBox="0 0 360 360"
                    fill="currentColor"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <g clip-path="url(#clip0_1103_889)">
                      <path
                        d="M180 33C262.845 33 330 100.155 330 183C330 265.845 262.845 333 180 333C97.155 333 30 265.845 30 183C30 100.155 97.155 33 180 33ZM180 93C176.022 93 172.206 94.5804 169.393 97.3934C166.58 100.206 165 104.022 165 108V183C165.001 186.978 166.582 190.793 169.395 193.605L214.395 238.605C217.224 241.337 221.013 242.849 224.946 242.815C228.879 242.781 232.641 241.203 235.422 238.422C238.203 235.641 239.781 231.879 239.815 227.946C239.849 224.013 238.337 220.224 235.605 217.395L195 176.79V108C195 104.022 193.42 100.206 190.607 97.3934C187.794 94.5804 183.978 93 180 93Z"
                        fill="currentColor"
                      />
                    </g>
                    <defs>
                      <clipPath id="clip0_1103_889">
                        <rect width="100%" height="100%" fill="currentColor" />
                      </clipPath>
                    </defs>
                  </svg>
                <% end %>
              </div>
            <% end %>
          </div>

          <div :if={not @is_submitted} id="quiz-actions" class="mt-4 flex w-full items-center gap-2">
            <%= if @current_quiz_question_idx > 0 do %>
              <button
                phx-click="prev-question"
                class="shrink-0 rounded-lg px-3 py-2 text-sm font-bold text-white hover:bg-white/10"
              >
                {gettext("Back")}
              </button>
            <% end %>

            <%= if @current_quiz_question_idx < length(@quiz.quiz_questions) - 1 do %>
              <button
                phx-click="next-question"
                class={[
                  "flex-1 rounded-lg px-3 py-2 text-sm font-bold",
                  @has_selection && "btn-gradient",
                  !@has_selection && "cursor-not-allowed bg-gray-700 text-gray-400"
                ]}
                disabled={not @has_selection}
              >
                {gettext("Next")}
              </button>
            <% else %>
              <%= if is_nil(@current_user) && !@quiz.allow_anonymous do %>
                <div class="flex min-w-0 flex-1 flex-col gap-1">
                  {link(
                    gettext("Sign in"),
                    target: "_blank",
                    to: ~p"/users/log_in",
                    class:
                      "btn-gradient inline w-full rounded-lg px-3 py-2 text-center text-sm font-bold"
                  )}
                  <p
                    id="quiz-sign-in-prompt"
                    class="text-center text-[10px] leading-tight text-gray-400"
                  >
                    {gettext("Please sign in to submit your answers")}
                  </p>
                </div>
              <% else %>
                <button
                  phx-click="submit-quiz"
                  class={[
                    "flex-1 rounded-lg px-3 py-2 text-sm font-bold",
                    @has_selection && "btn-gradient",
                    !@has_selection && "cursor-not-allowed bg-gray-700 text-gray-400"
                  ]}
                  disabled={not @has_selection}
                >
                  {gettext("Submit")}
                </button>
              <% end %>
            <% end %>
          </div>

          <div
            :if={
              @is_submitted && @quiz.show_results &&
                @current_quiz_question_idx <= length(@quiz.quiz_questions) - 1
            }
            id="quiz-review-actions"
            class="mt-4 flex w-full items-center justify-between gap-3"
          >
            <%= if (@current_quiz_question_idx > 0 && @current_quiz_question_idx <= length(@quiz.quiz_questions) - 1) do %>
              <button
                phx-click="prev-question"
                class="rounded-lg px-3 py-2 text-sm font-bold text-white hover:bg-white/10"
              >
                {gettext("Back")}
              </button>
            <% end %>

            <button
              :if={@current_quiz_question_idx <= length(@quiz.quiz_questions) - 1}
              phx-click="next-question"
              class="btn-gradient flex-1 rounded-lg px-3 py-2 text-sm font-bold"
            >
              {gettext("Next")}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def toggle_quiz(js \\ %JS{}) do
    js
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#collapsed-quiz",
      time: 50
    )
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#extended-quiz"
    )
  end

  defp check_current_question(assigns) do
    if assigns.current_quiz_responses != [] && not assigns.quiz.show_results do
      nil
    else
      Enum.at(assigns.quiz.quiz_questions, assigns.current_quiz_question_idx)
    end
  end
end
