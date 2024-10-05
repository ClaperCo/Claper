defmodule Claper.Quizzes.QuizQuestionOpt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quiz_question_opts" do
    field :content, :string
    field :is_correct, :boolean, default: false
    field :response_count, :integer, default: 0

    belongs_to :quiz_question, Claper.Quizzes.QuizQuestion

    timestamps()
  end

  @doc false
  def changeset(quiz_question_opt, attrs) do
    quiz_question_opt
    |> cast(attrs, [:content, :is_correct, :response_count, :quiz_question_id])
    |> validate_required([:content, :is_correct, :quiz_question_id])
  end
end
