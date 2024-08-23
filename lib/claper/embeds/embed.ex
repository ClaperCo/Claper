defmodule Claper.Embeds.Embed do
  use Ecto.Schema
  import Ecto.Changeset
  import ClaperWeb.Gettext

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          content: String.t(),
          provider: String.t(),
          enabled: boolean(),
          position: integer() | nil,
          attendee_visibility: boolean() | nil,
          presentation_file_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:title, :content, :position, :attendee_visibility]}
  schema "embeds" do
    field :title, :string
    field :content, :string
    field :provider, :string
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
      :provider,
      :presentation_file_id,
      :position,
      :attendee_visibility
    ])
    |> validate_required([
      :title,
      :content,
      :provider,
      :presentation_file_id,
      :position,
      :attendee_visibility
    ])
    |> validate_inclusion(:provider, ["youtube", "vimeo", "canva", "googleslides", "custom"])
    |> validate_provider_url()
  end

  defp validate_provider_url(changeset) do
    case get_field(changeset, :provider) do
      "youtube" ->
        changeset
        |> validate_format(:content, ~r/^https?:\/\/.+$/,
          message: gettext("Please enter a valid link starting with http:// or https://")
        )
        |> validate_format(:content, ~r/youtu\.be/,
          message: gettext("Please enter a valid %{provider} link", provider: "YouTube")
        )

      "canva" ->
        changeset
        |> validate_format(:content, ~r/^https?:\/\/.+$/,
          message: gettext("Please enter a valid link starting with http:// or https://")
        )
        |> validate_format(:content, ~r/canva\.com/,
          message: gettext("Please enter a valid %{provider} link", provider: "Canva")
        )

      "googleslides" ->
        changeset
        |> validate_format(:content, ~r/^https?:\/\/.+$/,
          message: gettext("Please enter a valid link starting with http:// or https://")
        )
        |> validate_format(:content, ~r/google\.com/,
          message: gettext("Please enter a valid %{provider} link", provider: "Google Slides")
        )

      "vimeo" ->
        changeset
        |> validate_format(:content, ~r/^https?:\/\/.+$/,
          message: gettext("Please enter a valid link starting with http:// or https://")
        )
        |> validate_format(:content, ~r/vimeo\.com/,
          message: gettext("Please enter a valid %{provider} link", provider: "Vimeo")
        )

      "custom" ->
        changeset
        |> validate_format(:content, ~r/<iframe.*?<\/iframe>/s,
          message: gettext("Please enter valid HTML content with an iframe tag")
        )

      _ ->
        changeset
    end
  end
end
