defmodule Claper.Quizzes.QuizQuestion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quiz_questions" do
    field :content, :string
    field :type, :string, default: "qcm"

    belongs_to :quiz, Claper.Quizzes.Quiz
    has_many :quiz_question_opts, Claper.Quizzes.QuizQuestionOpt

    timestamps()
  end

  @doc false
  def changeset(quiz_question, attrs) do
    quiz_question
    |> cast(attrs, [:content, :type, :quiz_id])
    |> validate_required([:content, :type, :quiz_id])
    |> cast_assoc(:quiz_question_opts)
  end
end
