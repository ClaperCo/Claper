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
    field :quiz_question_submission_id, :integer

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
      :user_id,
      :quiz_question_submission_id,
      :quiz_id,
      :quiz_question_id,
      :quiz_question_opt_id
    ])
    |> validate_required([
      :quiz_id,
      :quiz_question_id,
      :quiz_question_opt_id,
      :quiz_question_submission_id
    ])
    |> foreign_key_constraint(:quiz_question_submission_id)
    |> unique_constraint([:quiz_question_submission_id, :quiz_question_opt_id],
      name: :quiz_responses_submission_option_index
    )
  end
end
