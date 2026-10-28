defmodule Claper.Quizzes.Quiz do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          position: integer() | nil,
          enabled: boolean(),
          show_results: boolean(),
          allow_anonymous: boolean(),
          lti_line_item_url: String.t() | nil,
          lti_resource: Lti13.Resources.Resource.t() | nil,
          quiz_responses: [Claper.Quizzes.QuizResponse.t()] | nil,
          quiz_questions: [Claper.Quizzes.QuizQuestion.t()] | nil,
          presentation_file: Claper.Presentations.PresentationFile.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "quizzes" do
    field :title, :string
    field :position, :integer, default: 0
    field :enabled, :boolean, default: false
    field :show_results, :boolean, default: true
    field :allow_anonymous, :boolean, default: false
    field :lti_line_item_url, :string

    belongs_to :presentation_file, Claper.Presentations.PresentationFile
    belongs_to :lti_resource, Lti13.Resources.Resource

    has_many :quiz_questions, Claper.Quizzes.QuizQuestion,
      preload_order: [asc: :id],
      on_replace: :delete

    has_many :quiz_responses, Claper.Quizzes.QuizResponse

    timestamps()
  end

  @doc """
  Fields a presenter may edit through the quiz form. Ownership
  (`presentation_file_id`) and LTI wiring (`lti_resource_id`,
  `lti_line_item_url`) are never cast here: they decide which LMS the score
  reporter authenticates against and where it sends the bearer token.
  """
  def changeset(quiz, attrs) do
    quiz
    |> cast(attrs, [:title, :position, :enabled, :show_results, :allow_anonymous])
    |> validate_required([:title, :position, :presentation_file_id])
    |> cast_assoc(:quiz_questions,
      required: true,
      with: &Claper.Quizzes.QuizQuestion.changeset/2,
      sort_param: :quiz_questions_order,
      drop_param: :quiz_questions_delete
    )
  end

  @doc """
  Creation changeset. Callers must set the server-owned fields themselves
  instead of forwarding them from client params.
  """
  def create_changeset(quiz, attrs) do
    quiz
    |> cast(attrs, [:presentation_file_id, :lti_resource_id, :lti_line_item_url])
    |> changeset(attrs)
  end

  def update_line_item_changeset(quiz, attrs) do
    quiz
    |> cast(attrs, [:lti_line_item_url])
    |> validate_required([:lti_line_item_url])
  end
end
