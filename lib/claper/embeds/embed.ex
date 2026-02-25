defmodule Claper.Embeds.Embed do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: ClaperWeb.Gettext

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
        |> validate_format(:content, ~r/(youtu\.be)|(youtube\.com)/,
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
        |> sanitize_custom_embed()

      _ ->
        changeset
    end
  end

  @allowed_iframe_attrs ~w(src width height frameborder allow allowfullscreen style title loading referrerpolicy sandbox)

  defp sanitize_custom_embed(%{valid?: false} = changeset), do: changeset

  defp sanitize_custom_embed(changeset) do
    content = get_field(changeset, :content)

    case Regex.run(~r/<iframe\s[^>]*?(?:\/>|>[\s\S]*?<\/iframe>)/i, content) do
      [iframe_tag] ->
        put_change(changeset, :content, sanitize_iframe_tag(iframe_tag))

      _ ->
        add_error(
          changeset,
          :content,
          gettext("Please enter valid HTML content with an iframe tag")
        )
    end
  end

  @allowed_boolean_attrs ~w(allowfullscreen sandbox)

  defp sanitize_iframe_tag(iframe_tag) do
    # Extract key="value" attributes
    value_attrs =
      Regex.scan(~r/([\w-]+)\s*=\s*(?:"([^"]*?)"|'([^']*?)')/i, iframe_tag)
      |> Enum.filter(fn [_, name | _] -> String.downcase(name) in @allowed_iframe_attrs end)
      |> Enum.reject(fn [_, name, value | _] ->
        String.downcase(name) == "src" and String.trim(value) =~ ~r/^javascript:/i
      end)
      |> Enum.map(fn [_, name, value | _rest] ->
        ~s(#{String.downcase(name)}="#{String.replace(value, "\"", "&quot;")}")
      end)

    # Extract standalone boolean attributes (e.g., allowfullscreen)
    value_attr_names =
      Regex.scan(~r/([\w-]+)\s*=/i, iframe_tag)
      |> Enum.map(fn [_, name] -> String.downcase(name) end)
      |> MapSet.new()

    boolean_attrs =
      Regex.scan(~r/\s([\w-]+)(?=[\s>\/])/i, iframe_tag)
      |> Enum.map(fn [_, name] -> String.downcase(name) end)
      |> Enum.filter(&(&1 in @allowed_boolean_attrs))
      |> Enum.reject(&MapSet.member?(value_attr_names, &1))
      |> Enum.uniq()

    all_attrs = Enum.join(value_attrs ++ boolean_attrs, " ")

    if all_attrs == "", do: "<iframe></iframe>", else: "<iframe #{all_attrs}></iframe>"
  end
end
