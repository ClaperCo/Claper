defmodule Claper.Presentations.PresentationState do
  use Ecto.Schema
  import Ecto.Changeset

  schema "presentation_states" do
    field :position, :integer
    field :chat_visible, :boolean
    field :poll_visible, :boolean
    field :join_screen_visible, :boolean
    field :banned, {:array, :string}, default: []

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    timestamps()
  end

  @doc false
  def changeset(presentation_state, attrs) do
    presentation_state
    |> cast(attrs, [:position, :chat_visible, :poll_visible, :join_screen_visible, :banned])
    |> validate_required([])
  end
end
