defmodule Claper.Quizzes.Quiz do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quizzes" do
    field :title, :string
    field :position, :integer, default: 0
    field :enabled, :boolean, default: false
    field :show_results, :boolean, default: false
    field :lti_line_item_url, :string

    belongs_to :presentation_file, Claper.Presentations.PresentationFile
    belongs_to :lti_resource, Lti13.Resources.Resource

    has_many :quiz_questions, Claper.Quizzes.QuizQuestion,
      preload_order: [asc: :id],
      on_replace: :delete

    has_many :quiz_responses, Claper.Quizzes.QuizResponse

    timestamps()
  end

  @doc false
  def changeset(quiz, attrs) do
    quiz
    |> cast(attrs, [
      :title,
      :position,
      :presentation_file_id,
      :enabled,
      :show_results,
      :lti_resource_id,
      :lti_line_item_url
    ])
    |> validate_required([:title, :position, :presentation_file_id])
    |> cast_assoc(:quiz_questions,
      required: true,
      with: &Claper.Quizzes.QuizQuestion.changeset/2,
      sort_param: :quiz_questions_order,
      drop_param: :quiz_questions_delete
    )
  end

  def update_line_item_changeset(quiz, attrs) do
    quiz
    |> cast(attrs, [:lti_line_item_url])
    |> validate_required([:lti_line_item_url])
  end
end
