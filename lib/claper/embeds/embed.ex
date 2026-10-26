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
        sanitize_custom_embed(changeset)

      _ ->
        changeset
    end
  end

  @allowed_iframe_attrs ~w(src width height frameborder allow allowfullscreen style title loading referrerpolicy sandbox)
  @size_styles ~w(width height min-width max-width min-height max-height border-radius)

  @doc """
  Parses custom embed HTML into attributes for a single HTTP(S) iframe.

  Use this at render time as well as on writes: stored embeds may predate validation.
  No surrounding HTML, iframe contents, event handlers or srcdoc are retained.
  """
  def custom_iframe_attributes(content) when is_binary(content) do
    with {:ok, document} <-
           Floki.parse_fragment(content, html_parser: Floki.HTMLParser.Mochiweb),
         [{"iframe", attrs, _children}] <- Floki.find(document, "iframe"),
         true <- unique_attributes?(attrs),
         {"src", src} <- List.keyfind(attrs, "src", 0),
         true <- safe_iframe_url?(src) do
      attrs =
        attrs
        |> Enum.filter(fn {name, _value} -> name in @allowed_iframe_attrs end)
        |> Enum.map(fn
          {"src", src} -> {"src", String.trim(src)}
          {"style", style} -> {"style", safe_iframe_style(style)}
          attr -> attr
        end)

      {:ok, attrs}
    else
      _ -> :error
    end
  end

  def custom_iframe_attributes(_content), do: :error

  defp sanitize_custom_embed(%{valid?: false} = changeset), do: changeset

  defp sanitize_custom_embed(changeset) do
    case custom_iframe_attributes(get_field(changeset, :content)) do
      {:ok, attrs} ->
        put_change(changeset, :content, Floki.raw_html({"iframe", attrs, []}, encode: true))

      :error ->
        add_error(
          changeset,
          :content,
          gettext("Please enter valid HTML content with an iframe tag")
        )
    end
  end

  defp unique_attributes?(attrs) do
    names = Enum.map(attrs, fn {name, _value} -> name end)
    length(names) == MapSet.size(MapSet.new(names))
  end

  defp safe_iframe_url?(src) do
    src = String.trim(src)

    # Browsers remove ASCII tabs/newlines when interpreting URL schemes, and
    # treat backslashes as slashes in HTTP URLs. Reject these ambiguities.
    with false <- Regex.match?(~r/[\x00-\x20\x7F\\]/u, src),
         {:ok, %URI{scheme: scheme, host: host}} <- URI.new(src) do
      scheme in ["http", "https"] and is_binary(host) and host != ""
    else
      _ -> false
    end
  end

  defp safe_iframe_style(style) do
    style
    |> String.split(";", trim: true)
    |> Enum.flat_map(&safe_style_declaration/1)
    |> Enum.join(";")
  end

  defp safe_style_declaration(declaration) do
    with [name, value] <- String.split(declaration, ":", parts: 2),
         name = name |> String.trim() |> String.downcase(),
         value = String.trim(value),
         true <- safe_style_value?(name, value) do
      ["#{name}:#{value}"]
    else
      _ -> []
    end
  end

  defp safe_style_value?(name, value) when name in @size_styles do
    Regex.match?(~r/^(?:0|auto|\d+(?:\.\d+)?(?:px|%|em|rem|vh|vw))$/i, value)
  end

  defp safe_style_value?("border", value), do: value in ["0", "none"]
  defp safe_style_value?(_name, _value), do: false
end
