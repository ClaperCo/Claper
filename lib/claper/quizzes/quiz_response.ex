defmodule Claper.Quizzes.QuizResponse do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          attendee_identifier: String.t() | nil,
          quiz: Claper.Quizzes.Quiz.t() | nil,
          quiz_question: Claper.Quizzes.QuizQuestion.t() | nil,
          quiz_question_opt: Claper.Quizzes.QuizQuestionOpt.t() | nil,
          user: Claper.Accounts.User.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "quiz_responses" do
    field :attendee_identifier, :string

    belongs_to :quiz, Claper.Quizzes.Quiz
    belongs_to :quiz_question, Claper.Quizzes.QuizQuestion
    belongs_to :quiz_question_opt, Claper.Quizzes.QuizQuestionOpt
    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(quiz_response, attrs) do
    quiz_response
    |> cast(attrs, [
      :attendee_identifier,
      :quiz_id,
      :quiz_question_id,
      :quiz_question_opt_id
    ])
    |> validate_required([:quiz_id, :quiz_question_id, :quiz_question_opt_id])
  end
end
