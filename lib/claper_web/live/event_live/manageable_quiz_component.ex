defmodule ClaperWeb.EventLive.ManageableQuizComponent do
  use ClaperWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket |> assign(current_question_idx: -1) |> assign_new(:current_question, fn -> nil end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={"#{@id}"}
      class={"#{if @quiz.show_results, do: "opacity-100", else: "opacity-0"} h-full w-full flex flex-col justify-center bg-black/90 absolute z-30 left-1/2 top-1/2 transform -translate-y-1/2 -translate-x-1/2 p-10 transition-opacity"}
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
          <p class="font-semibold text-2xl">{gettext("Average score")}:</p>
          <p class="font-semibold text-7xl">
            {Claper.Quizzes.calculate_average_score(@quiz.id)}/{length(@quiz.quiz_questions)}
          </p>
        </div>

        <div
          :if={@current_question_idx >= 0}
          class={"#{if @iframe, do: "space-y-5", else: "space-y-8"} flex flex-col text-white text-center"}
        >
          <%= for {opt, _idx} <- Enum.with_index(Enum.at(@quiz.quiz_questions, @current_question_idx).quiz_question_opts) do %>
            <div class={"bg-gray-500 px-5 py-5 rounded-xl flex justify-between items-center relative text-white #{if opt.is_correct, do: "bg-green-600"} #{if not opt.is_correct, do: ""}"}>
              <div class="bg-linear-to-r from-primary-500 to-secondary-500 h-full absolute left-0 transition-all rounded-l-3xl">
              </div>
              <div class="flex space-x-3 justify-between w-full items-center z-10 text-left">
                <span class="flex-1 pr-2 text-3xl">{opt.content}</span>
                <span class="text-xl">{opt.percentage}% ({opt.response_count})</span>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
