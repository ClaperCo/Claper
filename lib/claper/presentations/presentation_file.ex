defmodule Claper.Presentations.PresentationFile do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          hash: String.t() | nil,
          length: integer() | nil,
          status: String.t() | nil,
          slide_order: [integer()] | nil,
          event_id: integer() | nil,
          polls: [Claper.Polls.Poll.t()] | nil,
          forms: [Claper.Forms.Form.t()] | nil,
          embeds: [Claper.Embeds.Embed.t()] | nil,
          quizzes: [Claper.Quizzes.Quiz.t()] | nil,
          scales: [Claper.Scales.Scale.t()] | nil,
          presentation_state: Claper.Presentations.PresentationState.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "presentation_files" do
    field :hash, :string
    field :length, :integer
    field :status, :string
    field :slide_order, {:array, :integer}

    belongs_to :event, Claper.Events.Event
    has_many :polls, Claper.Polls.Poll
    has_many :forms, Claper.Forms.Form
    has_many :embeds, Claper.Embeds.Embed
    has_many :quizzes, Claper.Quizzes.Quiz
    has_many :scales, Claper.Scales.Scale
    has_many :transcriptions, Claper.Transcriptions.Transcription
    has_one :transcription_config, Claper.Transcriptions.TranscriptionConfig
    has_one :presentation_state, Claper.Presentations.PresentationState, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(presentation_file, attrs) do
    presentation_file
    |> cast(attrs, [:length, :status, :hash, :event_id, :slide_order])
    |> cast_assoc(:presentation_state)
  end
end
