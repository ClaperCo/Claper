defmodule Claper.Quizzes do
  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Accounts.User

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
  def list_quizzes_at_position(presentation_file_id, position) do
    from(q in Quiz,
      where: q.presentation_file_id == ^presentation_file_id and q.position == ^position,
      order_by: [asc: q.id]
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

      iex> get_quiz!(123, [:quiz_questions, quiz_questions: :quiz_question_opts])
      %Quiz{}

      iex> get_quiz!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quiz!(id, preload \\ []) do
    Quiz
    |> Repo.get!(id)
    |> Repo.preload(preload)
    |> set_percentages()
  end

  @doc """
  Gets a single quiz for a given position.

  ## Examples

      iex> get_quiz_current_position(123, 0)
      %Quiz{}

  """
  def get_quiz_current_position(presentation_file_id, position) do
    from(q in Quiz,
      where:
        q.position == ^position and q.presentation_file_id == ^presentation_file_id and
          q.enabled == true
    )
    |> Repo.one()
    |> Repo.preload([:quiz_questions, quiz_questions: :quiz_question_opts])
    |> set_percentages()
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
    |> case do
      {:ok, quiz} ->
        if attrs["lti_resource_id"] do
          Claper.Workers.QuizLti.create(quiz.id) |> Oban.insert()
        end

        presentation_file =
          Claper.Presentations.get_presentation_file!(quiz.presentation_file_id, [
            :event
          ])

        broadcast({:ok, quiz, presentation_file.event.uuid}, :quiz_created)

        {:ok, quiz}

      error ->
        error
    end
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
      {:ok, updated_quiz} ->
        if quiz.lti_resource_id do
          Claper.Workers.QuizLti.edit(quiz.id) |> Oban.insert()
        end

        broadcast({:ok, updated_quiz, event_uuid}, :quiz_updated)

      error ->
        error
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
    case Repo.delete(quiz) do
      {:ok, quiz} ->
        broadcast({:ok, quiz, event_uuid}, :quiz_deleted)
        {:ok, quiz}

      error ->
        error
    end
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

  @doc """
  Adds a new quiz question to a quiz changeset.

  Creates a new question with two default empty options and appends it to the existing questions.

  ## Parameters

    - changeset: The quiz changeset to add the question to.

  ## Returns

  The updated changeset with the new question added.

  ## Examples

      iex> add_quiz_question(quiz_changeset)
      %Ecto.Changeset{}

  """
  def add_quiz_question(changeset) do
    existing_questions = Ecto.Changeset.get_field(changeset, :quiz_questions, [])

    new_question = %QuizQuestion{
      quiz_question_opts: [
        %QuizQuestionOpt{},
        %QuizQuestionOpt{}
      ]
    }

    new_question_changeset = Ecto.Changeset.change(new_question)

    updated_questions = existing_questions ++ [new_question_changeset]

    Ecto.Changeset.put_assoc(changeset, :quiz_questions, updated_questions)
  end

  @doc """
  Submits quiz responses for a user.

  Records the user's selected options and increments response counts.

  ## Parameters

    - user_id: The ID of the user submitting responses
    - quiz_opts: List of selected quiz options
    - quiz_id: The ID of the quiz being submitted

  ## Returns

  Broadcasts the updated quiz on successful submission.

  ## Examples

      iex> submit_quiz(123, quiz_opts, 456)
      {:ok, quiz}

  """

  # Pattern match on user, from user we create QuizResponse struct
  # def submit_quiz(user_id, quiz_opts, quiz_id)
  #     when is_number(user_id) and is_list(quiz_opts) do
  #   quiz_opts = Enum.with_index(quiz_opts)

  #   case Enum.reduce(quiz_opts, Ecto.Multi.new(), fn {opt, index}, multi ->
  #          unique_key = "#{opt.id}_#{user_id + index}"

  #          multi
  #          |> Ecto.Multi.update(
  #            "update_quiz_opt_#{unique_key}",
  #            QuizQuestionOpt.changeset(opt, %{"response_count" => opt.response_count + 1})
  #          )
  #          |> Ecto.Multi.insert(
  #            "insert_quiz_response_#{unique_key}",
  #            QuizResponse.changeset(%QuizResponse{}, %{
  #              user_id: user_id,
  #              quiz_question_opt_id: opt.id,
  #              quiz_question_id: opt.quiz_question_id,
  #              quiz_id: quiz_id
  #            })
  #          )
  #        end)
  #        |> Repo.transact() do
  #     {:ok, _} ->
  #       quiz = get_quiz!(quiz_id, [:quiz_questions, quiz_questions: :quiz_question_opts])
  #       Lti13.QuizScoreReporter.report_quiz_score(quiz, user_id)
  #       {:ok, quiz}
  #   end
  # end

  def submit_quiz(%User{} = user, quiz_opts, quiz_id) do
    quiz_opts = Enum.with_index(quiz_opts)

    case Enum.reduce(quiz_opts, Ecto.Multi.new(), fn {opt, index}, multi ->
           unique_key = "#{opt.id}_#{user.id + index}"

           multi
           |> Ecto.Multi.update(
             "update_quiz_opt_#{unique_key}",
             QuizQuestionOpt.changeset(opt, %{"response_count" => opt.response_count + 1})
           )
           |> Ecto.Multi.insert(
             "insert_quiz_response_#{unique_key}",
             Ecto.build_assoc(user, :quiz_responses, %{
               quiz_question_opt_id: opt.id,
               quiz_question_id: opt.quiz_question_id,
               quiz_id: quiz_id
             })
           )
         end)
         |> Repo.transact() do
      {:ok, _} ->
        quiz = get_quiz!(quiz_id, [:quiz_questions, quiz_questions: :quiz_question_opts])
        Lti13.QuizScoreReporter.report_quiz_score(quiz, user.id)
        {:ok, quiz}
    end
  end

  def submit_quiz(attendee_identifier, quiz_opts, quiz_id)
      when is_binary(attendee_identifier) and is_list(quiz_opts) do
    case Enum.reduce(quiz_opts, Ecto.Multi.new(), fn opt, multi ->
           multi
           |> Ecto.Multi.update(
             {:update_quiz_opt, opt.id},
             QuizQuestionOpt.changeset(opt, %{"response_count" => opt.response_count + 1})
           )
           |> Ecto.Multi.insert(
             {:insert_quiz_response, opt.id},
             QuizResponse.changeset(%QuizResponse{}, %{
               attendee_identifier: attendee_identifier,
               quiz_question_opt_id: opt.id,
               quiz_question_id: opt.quiz_question_id,
               quiz_id: quiz_id
             })
           )
         end)
         |> Repo.transact() do
      {:ok, _} ->
        quiz = get_quiz!(quiz_id, [:quiz_questions, quiz_questions: :quiz_question_opts])
        {:ok, quiz}
    end
  end

  @doc """
  Calculates the quiz score for a given user, handling multiple correct answers per question.

  Takes a user_id or attendee_identifier and returns their score for the specified quiz.

  ## Parameters

    - user_id: Integer user ID or string attendee_identifier
    - quiz_id: The ID of the quiz to calculate score for

  ## Returns

  A tuple containing {correct_answers, total_questions}.

  ## Examples

      iex> calculate_user_score(123, quiz_id)
      {3, 4}

      iex> calculate_user_score("abc123", quiz_id)
      {3, 4}

  """
  def calculate_user_score(user_id, quiz_id) when is_number(user_id) or is_binary(user_id) do
    # Get the user's responses
    responses = get_quiz_responses(user_id, quiz_id)

    # Get quiz with questions and correct answers
    quiz = get_quiz!(quiz_id, [:quiz_questions, quiz_questions: :quiz_question_opts])

    # Count correct responses per question
    correct_count =
      quiz.quiz_questions
      |> Enum.count(fn question ->
        # Get all user responses for this question
        question_responses = Enum.filter(responses, &(&1.quiz_question_id == question.id))
        # Get all correct options for this question
        correct_opts = Enum.filter(question.quiz_question_opts, & &1.is_correct)

        # User must select all correct options and no incorrect ones
        user_opt_ids = Enum.map(question_responses, & &1.quiz_question_opt_id) |> MapSet.new()
        correct_opt_ids = Enum.map(correct_opts, & &1.id) |> MapSet.new()

        MapSet.equal?(user_opt_ids, correct_opt_ids)
      end)

    {correct_count, length(quiz.quiz_questions)}
  end

  @doc """
  Calculates the average quiz score across all participants.

  Takes a quiz_id and returns the average score as a percentage.

  ## Parameters

    - quiz_id: The ID of the quiz to calculate average score for

  ## Returns

  A float representing the average score percentage.

  ## Examples

      iex> calculate_average_score(123)
      75.5

  """
  def calculate_average_score(quiz_id) do
    # Get quiz with questions and correct answers
    quiz = get_quiz!(quiz_id, [:quiz_questions, quiz_questions: :quiz_question_opts])

    # Get all responses grouped by user/attendee
    responses =
      from(r in QuizResponse,
        where: r.quiz_id == ^quiz_id,
        select: %{
          user_id: r.user_id,
          attendee_identifier: r.attendee_identifier,
          quiz_question_id: r.quiz_question_id,
          quiz_question_opt_id: r.quiz_question_opt_id
        }
      )
      |> Repo.all()

    # Group responses by user_id or attendee_identifier
    responses_by_user =
      responses
      |> Enum.group_by(fn response ->
        case response.user_id do
          nil -> response.attendee_identifier
          id -> id
        end
      end)

    scores =
      Enum.map(responses_by_user, fn {_user_id, user_responses} ->
        correct_count =
          quiz.quiz_questions
          |> Enum.count(fn question ->
            # Get user responses for this question
            question_responses =
              Enum.filter(user_responses, &(&1.quiz_question_id == question.id))

            # Get correct options for this question
            correct_opts = Enum.filter(question.quiz_question_opts, & &1.is_correct)

            # Check if user selected all correct options and no incorrect ones
            user_opt_ids = Enum.map(question_responses, & &1.quiz_question_opt_id) |> MapSet.new()
            correct_opt_ids = Enum.map(correct_opts, & &1.id) |> MapSet.new()

            MapSet.equal?(user_opt_ids, correct_opt_ids)
          end)

        correct_count
      end)

    case length(scores) do
      0 ->
        0

      n ->
        avg = Enum.sum(scores) / n
        if avg == trunc(avg), do: trunc(avg), else: avg
    end
  end

  @doc """
  Get number of submissions for a given quiz_id

  ## Examples

      iex> get_number_submissions(quiz_id)
      12

  """
  def get_submission_count(quiz_id) do
    from(r in QuizResponse,
      where: r.quiz_id == ^quiz_id,
      select:
        count(
          fragment("DISTINCT COALESCE(?, CAST(? AS varchar))", r.attendee_identifier, r.user_id)
        )
    )
    |> Repo.one()
  end

  @doc """
  Calculate percentage of all quiz questions for a given quiz.

  ## Examples

      iex> set_percentages(quiz)
      %Quiz{}

  """
  def set_percentages(%Quiz{quiz_questions: quiz_questions} = quiz)
      when is_list(quiz_questions) do
    %{
      quiz
      | quiz_questions: Enum.map(quiz_questions, &set_question_percentages/1)
    }
  end

  def set_percentages(quiz), do: quiz

  @doc """
  Calculate percentage of all quiz question options for a given quiz.

  ## Examples

      iex> set_question_percentages(quiz)
      %Quiz{}

  """
  def set_question_percentages(
        %QuizQuestion{quiz_question_opts: quiz_question_opts} =
          quiz_question
      )
      when is_list(quiz_question_opts) do
    total =
      Enum.map(quiz_question.quiz_question_opts, fn o -> o.response_count end) |> Enum.sum()

    %{
      quiz_question
      | quiz_question_opts:
          quiz_question.quiz_question_opts
          |> Enum.map(fn o -> %{o | percentage: calculate_percentage(o, total)} end)
    }
  end

  def set_question_percentages(quiz_question), do: quiz_question

  defp calculate_percentage(opt, total) do
    if total > 0,
      do: Float.round(opt.response_count / total * 100) |> :erlang.float_to_binary(decimals: 0),
      else: 0
  end

  @doc """
  Gets a all quiz_response.


  ## Examples

      iex> get_quiz_responses!(321, 123)
      [%QuizResponse{}]

  """
  def get_quiz_responses(user_id, quiz_id) when is_number(user_id) do
    from(p in QuizResponse,
      where: p.quiz_id == ^quiz_id and p.user_id == ^user_id,
      order_by: [asc: p.id]
    )
    |> Repo.all()
  end

  def get_quiz_responses(attendee_identifier, quiz_id) do
    from(p in QuizResponse,
      where: p.quiz_id == ^quiz_id and p.attendee_identifier == ^attendee_identifier,
      order_by: [asc: p.id]
    )
    |> Repo.all()
  end

  @doc """
  Add an empty quiz opt to a quiz changeset.
  """
  def add_quiz_question_opt(changeset, question_index) do
    existing_questions = Ecto.Changeset.get_field(changeset, :quiz_questions, [])

    new_opt = %QuizQuestionOpt{}
    new_opt_changeset = Ecto.Changeset.change(new_opt)

    updated_questions =
      List.update_at(existing_questions, question_index, fn question ->
        question_changeset = Ecto.Changeset.change(question)

        existing_opts = Ecto.Changeset.get_field(question_changeset, :quiz_question_opts, [])
        updated_opts = existing_opts ++ [new_opt_changeset]

        Ecto.Changeset.put_change(question_changeset, :quiz_question_opts, updated_opts)
      end)

    Ecto.Changeset.put_assoc(changeset, :quiz_questions, updated_questions)
  end

  def disable_all(presentation_file_id, position) do
    from(q in Quiz,
      where: q.presentation_file_id == ^presentation_file_id and q.position == ^position
    )
    |> Repo.update_all(set: [enabled: false])
  end

  def set_enabled(id) do
    get_quiz!(id)
    |> Ecto.Changeset.change(enabled: true)
    |> Repo.update()
  end

  def set_disabled(id) do
    get_quiz!(id)
    |> Ecto.Changeset.change(enabled: false)
    |> Repo.update()
  end

  defp broadcast({:ok, quiz, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, quiz}
    )

    {:ok, quiz}
  end
end
