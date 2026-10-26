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

  @provider_names %{
    "youtube" => "YouTube",
    "vimeo" => "Vimeo",
    "canva" => "Canva",
    "googleslides" => "Google Slides"
  }
  @youtube_hosts ~w(youtube.com www.youtube.com m.youtube.com youtube-nocookie.com
                    www.youtube-nocookie.com)
  @vimeo_hosts ~w(vimeo.com www.vimeo.com player.vimeo.com)

  defp validate_provider_url(changeset) do
    case get_field(changeset, :provider) do
      provider when provider in ["youtube", "vimeo", "canva", "googleslides"] ->
        validate_change(changeset, :content, &validate_provider_link(provider, &1, &2))

      "custom" ->
        sanitize_custom_embed(changeset)

      _ ->
        changeset
    end
  end

  defp validate_provider_link(provider, :content, content) do
    case provider_embed_url(provider, content) do
      {:ok, _url} ->
        []

      :error ->
        [
          content:
            gettext("Please enter a valid %{provider} link", provider: @provider_names[provider])
        ]
    end
  end

  @doc """
  Builds the iframe URL for a YouTube, Vimeo, Canva or Google Slides link.

  Returns `:error` unless the link parses as an HTTP(S) URL whose host belongs to
  the provider. YouTube and Vimeo frames are built from the validated video id on
  the provider's player host; Canva (any `canva.com` host) and Google Slides
  (exactly `docs.google.com`) URLs are rebuilt from their parsed parts over HTTPS.
  Use this at render time as well as on writes: stored embeds may predate
  validation.
  """
  def provider_embed_url("youtube", content) do
    with {:ok, uri} <- parse_iframe_url(content),
         id when is_binary(id) <- youtube_video_id(uri),
         true <- Regex.match?(~r/^[A-Za-z0-9_-]{11}$/, id) do
      {:ok, "https://www.youtube.com/embed/" <> id}
    else
      _ -> :error
    end
  end

  def provider_embed_url("vimeo", content) do
    with {:ok, %URI{host: host} = uri} when host in @vimeo_hosts <- parse_iframe_url(content),
         {id, hash} <- vimeo_video(uri) do
      query = if hash, do: "?h=" <> hash, else: ""
      {:ok, "https://player.vimeo.com/video/" <> id <> query}
    else
      _ -> :error
    end
  end

  def provider_embed_url("canva", content) do
    with {:ok, uri} <- parse_iframe_url(content),
         true <- uri.host == "canva.com" or String.ends_with?(uri.host, ".canva.com") do
      query = if uri.query in [nil, ""], do: "embed", else: uri.query <> "&embed"
      {:ok, URI.to_string(%{uri | scheme: "https", port: nil, query: query, fragment: nil})}
    else
      _ -> :error
    end
  end

  def provider_embed_url("googleslides", content) do
    case parse_iframe_url(content) do
      {:ok, %URI{host: "docs.google.com"} = uri} ->
        path = String.replace(uri.path || "", "/pub", "/embed")
        {:ok, URI.to_string(%{uri | scheme: "https", port: nil, path: path, fragment: nil})}

      _ ->
        :error
    end
  end

  def provider_embed_url(_provider, _content), do: :error

  defp youtube_video_id(%URI{host: "youtu.be", path: "/" <> id}), do: id

  defp youtube_video_id(%URI{host: host} = uri) when host in @youtube_hosts do
    case String.split(uri.path || "", "/", trim: true) do
      ["watch"] -> query_param(uri, "v")
      [kind, id] when kind in ~w(embed shorts live v) -> id
      _ -> nil
    end
  end

  defp youtube_video_id(_uri), do: nil

  # Supports vimeo.com/ID, vimeo.com/ID/HASH, player.vimeo.com/video/ID?h=HASH and
  # paths such as vimeo.com/channels/NAME/ID.
  defp vimeo_video(uri) do
    segments = String.split(uri.path || "", "/", trim: true)

    case Enum.drop_while(segments, &(not Regex.match?(~r/^\d+$/, &1))) do
      [id, hash | _] -> {id, vimeo_hash(hash)}
      [id] -> {id, vimeo_hash(query_param(uri, "h"))}
      [] -> nil
    end
  end

  defp vimeo_hash(hash) when is_binary(hash) do
    if Regex.match?(~r/^[0-9a-zA-Z]+$/, hash), do: hash
  end

  defp vimeo_hash(_hash), do: nil

  # Values are matched against strict patterns by the callers, so no decoding.
  defp query_param(%URI{query: query}, name) when is_binary(query) do
    Enum.find_value(String.split(query, "&"), fn param ->
      case String.split(param, "=", parts: 2) do
        [^name, value] -> value
        _ -> nil
      end
    end)
  end

  defp query_param(_uri, _name), do: nil

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

  defp safe_iframe_url?(src), do: match?({:ok, _uri}, parse_iframe_url(src))

  defp parse_iframe_url(src) when is_binary(src) do
    src = String.trim(src)

    # Browsers remove ASCII tabs/newlines when interpreting URL schemes, and
    # treat backslashes as slashes in HTTP URLs. Reject these ambiguities.
    with false <- Regex.match?(~r/[\x00-\x20\x7F\\]/u, src),
         {:ok, %URI{scheme: scheme, host: host} = uri} when scheme in ["http", "https"] <-
           URI.new(src),
         true <- is_binary(host) and host != "" do
      {:ok, %{uri | host: String.downcase(host), userinfo: nil}}
    else
      _ -> :error
    end
  end

  defp parse_iframe_url(_src), do: :error

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
