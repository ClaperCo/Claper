defmodule Claper.Embeds.Embed do
  use Ecto.Schema
  import Ecto.Changeset
  import ClaperWeb.Gettext

  @derive {Jason.Encoder, only: [:title, :content, :position, :attendee_visibility]}
  schema "embeds" do
    field :title, :string
    field :content, :string
    field :enabled, :boolean, default: true
    field :position, :integer, default: 0
    field :attendee_visibility, :boolean, default: false

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    timestamps()
  end

  @doc false
  def changeset(embed, attrs \\ %{}) do
    embed
    |> cast(attrs, [
      :enabled,
      :title,
      :content,
      :presentation_file_id,
      :position,
      :attendee_visibility
    ])
    |> validate_required([
      :title,
      :content,
      :presentation_file_id,
      :position,
      :attendee_visibility
    ])
    |> validate_format(:content, ~r/<iframe.*<\/iframe>/,
      message: gettext("Invalid embed format (should start with <iframe> and end with </iframe>)")
    )
  end
end
