defmodule ClaperWeb.EventLive.ManageableQuizComponent do
  use ClaperWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(current_question_idx: -1)
     |> assign_new(:chat_visible, fn -> true end)
     |> assign_new(:beside, fn -> true end)
     |> assign_new(:current_question, fn -> nil end)
     |> assign_new(:average_percent, fn -> 0 end)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if Map.has_key?(assigns, :quiz) do
        assign(
          socket,
          :average_percent,
          Claper.Quizzes.calculate_average_score_percent(assigns.quiz.id)
        )
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"#{@id}"} class={root_class(@beside, @quiz.show_results, @chat_visible)}>
      <div class={if @beside, do: "w-full", else: "w-full md:w-1/2 mx-auto h-full"}>
        <p class={[
          "text-white font-bold text-center",
          title_class(@beside, @iframe)
        ]}>
          <span :if={@current_question_idx < 0}>{@quiz.title}</span>
          <span :if={@current_question_idx >= 0}>
            {Enum.at(@quiz.quiz_questions, @current_question_idx).content}
          </span>
        </p>

        <div
          :if={@current_question_idx == -1}
          class={"#{if @iframe, do: "space-y-5", else: "space-y-8"} flex flex-col text-white text-center"}
        >
          <p class="font-semibold text-2xl">{gettext("Average score")}:</p>
          <p class={"font-semibold #{if @beside, do: "text-6xl", else: "text-7xl"}"}>
            {@average_percent}%
          </p>
        </div>

        <%!-- Like a poll: how the answers were distributed, the correct one in green. --%>
        <div
          :if={@current_question_idx >= 0}
          class={"#{if @iframe, do: "space-y-3", else: "space-y-4"} flex flex-col text-white text-center"}
        >
          <%= for opt <- Enum.at(@quiz.quiz_questions, @current_question_idx).quiz_question_opts do %>
            <div class={[
              "px-5 rounded-xl flex justify-between items-center relative overflow-hidden text-white",
              if(@iframe, do: "py-2", else: "py-4"),
              if(opt.is_correct, do: "bg-green-900 ring-2 ring-green-400", else: "bg-gray-500")
            ]}>
              <div
                style={"width: #{opt.percentage}%;"}
                class={[
                  "h-full absolute left-0 transition-all",
                  if(opt.is_correct, do: "bg-green-500", else: "bg-primary")
                ]}
              >
              </div>
              <div class="flex space-x-3 justify-between w-full items-center z-10 text-left">
                <span class={[
                  "flex-1 pr-2 flex items-center gap-x-2",
                  if(@beside, do: "text-2xl", else: "text-3xl")
                ]}>
                  <svg
                    :if={opt.is_correct}
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    class="w-6 h-6 shrink-0"
                    aria-hidden="true"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  <span>{opt.content}</span>
                </span>
                <span class="text-lg font-bold">{opt.percentage}% ({opt.response_count})</span>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Next to the slide the results sit in the left column; otherwise they cover
  # the whole screen as an overlay.
  defp root_class(true, show_results, chat_visible) do
    "#{ClaperWeb.EventLive.PresenterPanel.class(show_results, chat_visible)} flex flex-col justify-center overflow-y-auto bg-black p-6"
  end

  defp root_class(false, show_results, _chat_visible) do
    "#{if show_results, do: "opacity-100", else: "opacity-0 pointer-events-none"} h-full w-full flex flex-col justify-center bg-black/90 absolute z-30 left-1/2 top-1/2 transform -translate-y-1/2 -translate-x-1/2 p-10 transition-opacity"
  end

  defp title_class(true, true), do: "text-lg mb-4"
  defp title_class(true, false), do: "text-3xl mb-6"
  defp title_class(false, true), do: "text-xl mb-12"
  defp title_class(false, false), do: "text-5xl mb-24"
end
