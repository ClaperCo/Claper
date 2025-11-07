defmodule Claper.Polls.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          position: integer() | nil,
          total: integer() | nil,
          enabled: boolean() | nil,
          multiple: boolean() | nil,
          presentation_file_id: integer() | nil,
          poll_opts: [Claper.Polls.PollOpt.t()],
          poll_votes: [Claper.Polls.PollVote.t()] | nil,
          show_results: boolean() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:title, :position]}
  schema "polls" do
    field :title, :string
    field :position, :integer
    field :total, :integer, virtual: true
    field :enabled, :boolean
    field :multiple, :boolean
    field :show_results, :boolean

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    has_many :poll_opts, Claper.Polls.PollOpt,
      preload_order: [asc: :id],
      on_replace: :delete

    has_many :poll_votes, Claper.Polls.PollVote, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [
      :title,
      :presentation_file_id,
      :position,
      :enabled,
      :total,
      :multiple,
      :show_results
    ])
    |> cast_assoc(:poll_opts, required: true)
    |> validate_required([:title, :presentation_file_id, :position])
    |> validate_length(:title, max: 255)
  end
end
