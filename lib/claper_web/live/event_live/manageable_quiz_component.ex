defmodule ClaperWeb.EventLive.ManageableQuizComponent do
  use ClaperWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign_new(:current_question, fn -> nil end)
     |> assign_new(:average_score, fn -> 0 end)
     |> assign_new(:submission_count, fn -> 0 end)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if Map.has_key?(assigns, :quiz) do
        socket
        |> assign(:average_score, Claper.Quizzes.calculate_average_score(assigns.quiz.id))
        |> assign(:submission_count, Claper.Quizzes.get_submission_count(assigns.quiz.id))
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={"#{@id}"}
      class={"#{if Claper.Quizzes.Quiz.on_screen?(@quiz), do: "opacity-100", else: "opacity-0 pointer-events-none"} h-full w-full flex flex-col justify-center bg-black/90 absolute z-30 left-1/2 top-1/2 transform -translate-y-1/2 -translate-x-1/2 p-10 transition-opacity"}
    >
      <div class="w-full md:w-1/2 mx-auto h-full">
        <p class={"#{if @iframe, do: "text-xl mb-12", else: "text-5xl mb-24"} text-white font-bold text-center"}>
          <span :if={@current_question_idx < 0}>{@quiz.title}</span>
          <span :if={@current_question_idx >= 0}>
            {Enum.at(@quiz.quiz_questions, @current_question_idx).content}
          </span>
        </p>

        <div
          :if={@current_question_idx == -1}
          class={"#{if @iframe, do: "space-y-5", else: "space-y-8"} flex flex-col text-white text-center"}
        >
          <%= if @quiz.reveal_answers do %>
            <p class="font-semibold text-2xl">{gettext("Average score")}:</p>
            <p class="font-semibold text-7xl">
              {@average_score}/{length(@quiz.quiz_questions)}
            </p>
          <% else %>
            <p class="font-semibold text-2xl">{gettext("Total submissions")}:</p>
            <p class="font-semibold text-7xl">{@submission_count}</p>
          <% end %>
        </div>

        <div
          :if={@current_question_idx >= 0}
          class={"#{if @iframe, do: "space-y-5", else: "space-y-8"} flex flex-col text-white text-center"}
        >
          <%= for {opt, _idx} <- Enum.with_index(Enum.at(@quiz.quiz_questions, @current_question_idx).quiz_question_opts) do %>
            <div class={"#{if @quiz.reveal_answers && opt.is_correct, do: "bg-green-600", else: "bg-gray-500"} px-5 py-5 rounded-xl flex justify-between items-center relative text-white"}>
              <div class="bg-linear-to-r from-primary-500 to-secondary-500 h-full absolute left-0 transition-all rounded-l-3xl">
              </div>
              <div class="flex space-x-3 justify-between w-full items-center z-10 text-left">
                <span class="flex-1 pr-2 text-3xl">{opt.content}</span>
                <span :if={@quiz.show_results} class="text-xl">
                  {opt.percentage}% ({opt.response_count})
                </span>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
