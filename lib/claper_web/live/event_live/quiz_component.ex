defmodule ClaperWeb.EventLive.QuizComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    current_question = Enum.at(assigns.quiz.quiz_questions, assigns.current_quiz_question_idx)
    is_submitted = length(assigns.current_quiz_responses) > 0

    ~H"""
    <div>
      <div
        id="collapsed-quiz"
        class="bg-gray-900 py-3 px-6 text-black shadow-lg mx-auto rounded-full w-max hidden"
      >
        <div class="block w-full h-full cursor-pointer" phx-click={toggle_quiz()} phx-target={@myself}>
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
                stroke-
                linejoin="round"
                d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
              />
            </svg>
            <span class="font-bold"><%= gettext("See current quiz") %></span>
          </div>
        </div>
      </div>
      <div id="extended-quiz" class="bg-gray-900 w-full py-3 px-6 text-black shadow-lg rounded-md">
        <div class="block w-full h-full cursor-pointer" phx-click={toggle_quiz()} phx-target={@myself}>
          <div id="poll-pane" class="float-right mt-2">
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

          <p class="text-xs text-gray-500 my-1"><%= gettext("Current quiz") %></p>
          <%= if is_submitted do %>
            <p class="text-white text-lg font-semibold mb-2"><%= @quiz.title %></p>
          <% else %>
            <p class="text-white text-lg font-semibold mb-2"><%= current_question.content %></p>
            <p class="text-gray-600 text-sm mb-4">
              <%= @current_quiz_question_idx + 1 %>/<%= length(@quiz.quiz_questions) %>
            </p>
          <% end %>
        </div>
        <div>
          <div class="flex flex-col space-y-3 overflow-y-auto max-h-[500px]">
            <%= if not is_submitted do %>
              <%= for {opt, idx} <- Enum.with_index(current_question.quiz_question_opts) do %>
                <button
                  phx-click="select-quiz-question-opt"
                  phx-value-opt={opt.id}
                  class="bg-gray-500 px-3 py-2 rounded-xl flex justify-between items-center relative text-white"
                >
                  <div class="bg-gradient-to-r from-primary-500 to-secondary-500 h-full absolute left-0 transition-all rounded-l-3xl">
                  </div>
                  <div class="flex space-x-3 items-center z-10 text-left">
                    <%= if Enum.member?(@selected_quiz_question_opts, opt) do %>
                      <span class="h-5 w-5 mt-0.5 rounded-md point-select bg-white"></span>
                    <% else %>
                      <span class="h-5 w-5 mt-0.5 rounded-md point-select border-2 border-white">
                      </span>
                    <% end %>
                    <span class="flex-1 pr-2"><%= opt.content %></span>
                  </div>
                </button>
              <% end %>
            <% else %>
              <div class="text-gray-400 flex flex-col items-center justify-center font-semibold text-lg mt-4 mb-8">
                <%= if @quiz.show_results do %>
                  MY RESULTS
                <% else %>
                  <p><%= gettext("Waiting for results...") %></p>
                  <svg
                    class="w-32 h-32 mt-4"
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

          <div :if={not is_submitted}>
            <button
              :if={@current_quiz_question_idx > 0}
              phx-click="prev-question"
              class="px-3 py-2 text-white font-semibold mt-3 mb-4"
            >
              <%= gettext("Back") %>
            </button>

            <button
              :if={@current_quiz_question_idx < length(@quiz.quiz_questions) - 1}
              phx-click="next-question"
              class="px-3 py-2 text-white font-semibold bg-primary-500 hover:bg-primary-600 rounded-md mt-3 mb-4"
            >
              <%= gettext("Next") %>
            </button>

            <button
              :if={@current_quiz_question_idx == length(@quiz.quiz_questions) - 1}
              phx-click="submit-quiz"
              class="px-3 py-2 text-white font-semibold bg-primary-500 hover:bg-primary-600 rounded-md mt-3 mb-4"
            >
              <%= gettext("Submit") %>
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
end
