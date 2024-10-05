defmodule ClaperWeb.QuizLive.QuizComponent do
  alias Claper.Quizzes.QuizQuestionOpt
  use ClaperWeb, :live_component

  alias Claper.Quizzes

  @impl true
  def update(%{quiz: quiz} = assigns, socket) do
    changeset = Quizzes.change_quiz(quiz)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:dark, fn -> false end)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    quiz = Quizzes.get_quiz!(id)
    {:ok, _} = Quizzes.delete_quiz(socket.assigns.event_uuid, quiz)

    {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}
  end

  @impl true
  def handle_event("validate", %{"quiz" => quiz_params}, socket) do
    changeset =
      socket.assigns.quiz
      |> Quizzes.change_quiz(quiz_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"quiz" => quiz_params}, socket) do
    save_quiz(socket, socket.assigns.live_action, quiz_params)
  end

  @impl true
  def handle_event("add_quiz_question", _params, %{assigns: %{changeset: changeset}} = socket) do
    {:noreply, assign(socket, :changeset, changeset |> Quizzes.add_quiz_question())}
  end

  @impl true
  def handle_event("add_quiz_question_opt", %{"question_index" => index}, %{assigns: %{changeset: changeset}} = socket) do
    index = String.to_integer(index)
    {:noreply, assign(socket, :changeset, changeset |> Quizzes.add_quiz_question_opt(index))}
  end

  @impl true
  def handle_event("remove_quiz_question", %{"index" => index}, socket) do
    index = String.to_integer(index)
    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.update_change(:quiz_questions, fn questions ->
        List.delete_at(questions, index)
      end)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("remove_opt",
        %{"opt" => opt} = _params,
        %{assigns: %{changeset: changeset}} = socket
      ) do
    {opt, _} = Integer.parse(opt)

    quiz_opt = Enum.at(Ecto.Changeset.get_field(changeset, :quiz_question_opts), opt)

    {:noreply, assign(socket, :changeset, changeset |> Quizzes.remove_quiz_opt(quiz_opt))}
  end

  defp save_quiz(socket, :edit, quiz_params) do
    case Quizzes.update_quiz(
           socket.assigns.event_uuid,
           socket.assigns.quiz,
           quiz_params
         ) do
      {:ok, _quiz} ->
        {:noreply,
         socket
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_quiz(socket, :new, quiz_params) do
    case Quizzes.create_quiz(
           quiz_params
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("position", socket.assigns.position)
           |> Map.put("enabled", false)
         ) do
      {:ok, quiz} ->
        {:noreply,
         socket
         |> maybe_change_current_quiz(quiz)
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp maybe_change_current_quiz(socket, %{enabled: true} = quiz) do
    quiz = Quizzes.get_quiz!(quiz.id)

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event_uuid}",
      {:current_quiz, quiz}
    )

    socket
  end

  defp maybe_change_current_quiz(socket, _), do: socket

end
