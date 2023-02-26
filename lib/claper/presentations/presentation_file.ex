defmodule Claper.Presentations.PresentationFile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "presentation_files" do
    field :hash, :string
    field :length, :integer
    field :status, :string

    belongs_to :event, Claper.Events.Event
    has_many :polls, Claper.Polls.Poll
    has_many :forms, Claper.Forms.Form
    has_one :presentation_state, Claper.Presentations.PresentationState, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(presentation_file, attrs) do
    presentation_file
    |> cast(attrs, [:length, :status, :hash, :event_id])
    |> cast_assoc(:presentation_state)
  end
end
