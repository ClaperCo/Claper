defmodule Claper.Presentations.PresenterNote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "presenter_notes" do
    field :slide_position, :integer
    field :content, :string, default: ""

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    timestamps()
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:slide_position, :content, :presentation_file_id])
    |> validate_required([:slide_position, :presentation_file_id])
  end
end
