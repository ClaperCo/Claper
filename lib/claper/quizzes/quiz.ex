defmodule Claper.Quizzes.Quiz do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quizzes" do
    field :title, :string
    field :position, :integer, default: 0
    field :enabled, :boolean, default: false
    field :show_results, :boolean, default: false

    belongs_to :presentation_file, Claper.Presentations.PresentationFile
    has_many :quiz_questions, Claper.Quizzes.QuizQuestion

    timestamps()
  end

  @doc false
  def changeset(quiz, attrs) do
    quiz
    |> cast(attrs, [:title, :position, :presentation_file_id, :enabled, :show_results])
    |> validate_required([:title, :position, :presentation_file_id])
    |> cast_assoc(:quiz_questions)
  end
end
