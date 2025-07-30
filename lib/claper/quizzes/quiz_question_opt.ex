defmodule Claper.Quizzes.QuizQuestionOpt do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          content: String.t(),
          is_correct: boolean(),
          response_count: integer(),
          percentage: float() | nil,
          quiz_question: Claper.Quizzes.QuizQuestion.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "quiz_question_opts" do
    field :content, :string
    field :is_correct, :boolean, default: false
    field :response_count, :integer, default: 0
    field :percentage, :float, virtual: true

    belongs_to :quiz_question, Claper.Quizzes.QuizQuestion

    timestamps()
  end

  @doc false
  def changeset(quiz_question_opt, attrs) do
    quiz_question_opt
    |> cast(attrs, [:content, :is_correct, :response_count])
    |> validate_required([:content, :is_correct])
  end
end
