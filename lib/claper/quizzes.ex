defmodule Claper.Quizzes do
  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Quizzes.Quiz
  alias Claper.Quizzes.QuizQuestion
  alias Claper.Quizzes.QuizQuestionOpt
  alias Claper.Quizzes.QuizResponse

  @doc """
  Returns the list of quizzes for a given presentation file.

  ## Examples

      iex> list_quizzes(123)
      [%Quiz{}, ...]

  """
  def list_quizzes(presentation_file_id) do
    from(p in Quiz,
      where: p.presentation_file_id == ^presentation_file_id,
      order_by: [asc: p.id, asc: p.position]
    )
    |> Repo.all()
    |> Repo.preload([:quiz_questions, quiz_questions: :quiz_question_opts])
  end

  @doc """
  Returns the list of quizzes for a given presentation file and a given position.

  ## Examples

      iex> list_quizzes_at_position(123, 0)
      [%Quiz{}, ...]

  """
  def list_polls_at_position(presentation_file_id, position) do
    from(p in Quiz,
      where: p.presentation_file_id == ^presentation_file_id and p.position == ^position,
      order_by: [asc: p.id]
    )
    |> Repo.all()
    |> Repo.preload([:quiz_questions, quiz_questions: :quiz_question_opts])
  end



  @doc """
  Gets a single quiz by ID.

  Raises `Ecto.NoResultsError` if the Quiz does not exist.

  ## Parameters

    - id: The ID of the quiz.

  ## Examples

      iex> get_quiz!(123)
      %Quiz{}

      iex> get_quiz!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quiz!(id) do
    Quiz
    |> Repo.get!(id)
    |> Repo.preload([:quiz_questions, quiz_questions: :quiz_question_opts])
  end

  @doc """
  Creates a quiz.

  ## Parameters

    - attrs: A map of attributes for creating a quiz.

  ## Examples

      iex> create_quiz(%{field: value})
      {:ok, %Quiz{}}

      iex> create_quiz(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quiz(attrs \\ %{}) do
    %Quiz{}
    |> Quiz.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quiz.

  ## Parameters

    - quiz: The quiz struct to update.
    - attrs: A map of attributes to update.

  ## Examples

      iex> update_quiz(quiz, %{field: new_value})
      {:ok, %Quiz{}}

      iex> update_quiz(quiz, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quiz(event_uuid, %Quiz{} = quiz, attrs) do
    quiz
    |> Quiz.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, quiz} ->
        broadcast({:ok, quiz, event_uuid}, :quiz_updated)

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Deletes a quiz.

  ## Parameters

    - event_uuid: The UUID of the event.
    - quiz: The quiz struct to delete.

  ## Examples

      iex> delete_quiz(event_uuid, quiz)
      {:ok, %Quiz{}}

      iex> delete_quiz(event_uuid, quiz)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quiz(event_uuid, %Quiz{} = quiz) do
    {:ok, quiz} = Repo.delete(quiz)
    broadcast({:ok, quiz, event_uuid}, :quiz_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking quiz changes.

  ## Parameters

    - quiz: The quiz struct to create a changeset for.
    - attrs: A map of attributes (optional).

  ## Examples

      iex> change_quiz(quiz)
      %Ecto.Changeset{data: %Quiz{}}

  """
  def change_quiz(%Quiz{} = quiz, attrs \\ %{}) do
    Quiz.changeset(quiz, attrs)
  end

  def add_quiz_question(changeset) do
    changeset
    |> Ecto.Changeset.put_assoc(:quiz_questions, Ecto.Changeset.get_field(changeset, :quiz_questions) ++ [%QuizQuestion{
      quiz_question_opts: [
        %QuizQuestionOpt{},
        %QuizQuestionOpt{}
      ]
    }])
  end

  def remove_quiz_question(changeset, quiz_question) do
    changeset
    |> Ecto.Changeset.put_assoc(
      :quiz_questions,
      Ecto.Changeset.get_field(changeset, :quiz_questions) -- [quiz_question]
    )
  end

  @doc """
  Add an empty quiz opt to a quiz changeset.
  """
  def add_quiz_question_opt(changeset, question_index) do
    changeset
    |> Ecto.Changeset.put_assoc(:quiz_questions, Ecto.Changeset.get_field(changeset, :quiz_questions) |>  List.update_at(question_index, fn question ->
      Ecto.Changeset.put_assoc(question, :quiz_question_opts,
        (question.quiz_question_opts || []) ++ [%QuizQuestionOpt{}])
    end))
  end

  @doc """
  Remove a quiz question opt from a quiz question changeset.
  """
  def remove_quiz_question_opt(changeset, quiz_question_opt) do
    changeset
    |> Ecto.Changeset.put_assoc(
      :quiz_question_opts,
      Ecto.Changeset.get_field(changeset, :quiz_question_opts) -- [quiz_question_opt]
    )
  end

  defp broadcast({:error, _reason} = error, _quiz), do: error

  defp broadcast({:ok, quiz, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, quiz}
    )

    {:ok, quiz}
  end
end
