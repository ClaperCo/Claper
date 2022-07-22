defmodule Claper.Polls.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:title, :position]}
  schema "polls" do
    field :title, :string
    field :position, :integer
    field :total, :integer, virtual: true
    field :enabled, :boolean

    belongs_to :presentation_file, Claper.Presentations.PresentationFile
    has_many :poll_opts, Claper.Polls.PollOpt, on_replace: :delete
    has_many :poll_votes, Claper.Polls.PollVote, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [:title, :presentation_file_id, :position, :enabled, :total])
    |> cast_assoc(:poll_opts, required: true)
    |> validate_required([:title, :presentation_file_id, :position])
  end
end
