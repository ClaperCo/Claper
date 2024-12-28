defmodule ClaperWeb.QuizLive.QuizComponent do
  use ClaperWeb, :live_component

  alias Claper.Quizzes

  @impl true
  def update(%{quiz: quiz} = assigns, socket) do
    changeset = Quizzes.change_quiz(quiz)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:dark, fn -> false end)
     |> assign(:changeset, changeset)
     |> assign(:current_quiz_question_index, 0)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    quiz = Quizzes.get_quiz!(id, [:quiz_questions, quiz_questions: :quiz_question_opts])
    {:ok, _} = Quizzes.delete_quiz(socket.assigns.event.uuid, quiz)

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
  def handle_event(
        "add_quiz_question",
        _params,
        %{
          assigns: %{
            changeset: changeset
          }
        } = socket
      ) do
    {:noreply,
     socket
     |> assign(:changeset, changeset |> Quizzes.add_quiz_question())
     |> assign(
       :current_quiz_question_index,
       length(Ecto.Changeset.get_field(changeset, :quiz_questions))
     )}
  end

  @impl true
  def handle_event(
        "remove_quiz_question",
        _params,
        %{assigns: %{current_quiz_question_index: current_quiz_question_index}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:current_quiz_question_index, max(0, current_quiz_question_index - 1))}
  end

  @impl true
  def handle_event(
        "add_quiz_question_opt",
        %{"question_index" => index},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    index = String.to_integer(index)
    {:noreply, assign(socket, :changeset, changeset |> Quizzes.add_quiz_question_opt(index))}
  end

  @impl true
  def handle_event("set_current_quiz_question_index", %{"index" => index}, socket) do
    index = String.to_integer(index)
    {:noreply, assign(socket, :current_quiz_question_index, index)}
  end

  defp save_quiz(socket, :edit, quiz_params) do
    case Quizzes.update_quiz(
           socket.assigns.event.uuid,
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
    lti_resource = socket.assigns.event.lti_resource
    lti_resource_id = if lti_resource, do: lti_resource.id, else: nil

    case Quizzes.create_quiz(
           quiz_params
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("lti_resource_id", lti_resource_id)
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
    quiz = Quizzes.get_quiz!(quiz.id, [:quiz_questions, quiz_questions: :quiz_question_opts])

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:current_quiz, quiz}
    )

    socket
  end

  defp maybe_change_current_quiz(socket, _), do: socket
end
