defmodule Claper.Quizzes.QuizQuestion do
  use Ecto.Schema
  import Ecto.Changeset

  use Gettext, backend: ClaperWeb.Gettext

  @type t :: %__MODULE__{
          id: integer(),
          content: String.t(),
          type: String.t(),
          quiz: Claper.Quizzes.Quiz.t() | nil,
          quiz_question_opts: [Claper.Quizzes.QuizQuestionOpt.t()] | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "quiz_questions" do
    field :content, :string
    field :type, :string, default: "qcm"

    belongs_to :quiz, Claper.Quizzes.Quiz

    has_many :quiz_question_opts, Claper.Quizzes.QuizQuestionOpt,
      preload_order: [asc: :id],
      on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(quiz_question, attrs) do
    quiz_question
    |> cast(attrs, [:content, :type])
    |> validate_required([:content, :type])
    |> cast_assoc(:quiz_question_opts,
      required: true,
      with: &Claper.Quizzes.QuizQuestionOpt.changeset/2,
      sort_param: :quiz_question_opts_order,
      drop_param: :quiz_question_opts_delete
    )
    |> validate_at_least_one_correct_opt()
  end

  defp validate_at_least_one_correct_opt(changeset) do
    quiz_question_opts = get_field(changeset, :quiz_question_opts) || []
    has_correct_opt = Enum.any?(quiz_question_opts, & &1.is_correct)

    if has_correct_opt do
      changeset
    else
      add_error(changeset, :quiz_question_opts, gettext("must have at least one correct answer"))
    end
  end
end
