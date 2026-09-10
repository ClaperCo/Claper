defmodule Claper.Presentations do
  @moduledoc """
  The Presentations context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Presentations.PresentationFile

  @doc """
  Gets a single presentation_files.

  Raises `Ecto.NoResultsError` if the Presentation files does not exist.

  ## Examples

      iex> get_presentation_file!(123)
      %PresentationFile{}

      iex> get_presentation_file!(456)
      ** (Ecto.NoResultsError)

  """
  def get_presentation_file!(id, preload \\ []),
    do: Repo.get!(PresentationFile, id) |> Repo.preload(preload)

  def get_presentation_files_by_hash(hash) when is_binary(hash),
    do: Repo.all(from p in PresentationFile, where: p.hash == ^hash)

  def get_presentation_files_by_hash(hash) when is_nil(hash),
    do: []

  @doc """
  Returns a list of JPG slide URLs for a given presentation.

  When a `Claper.Presentations.PresentationFile{}` struct is provided, the
  function builds the list of URLs programmatically from the `hash` and
  `length` fields.

  When an integer or binary `hash` is provided, it queries the database for the
  associated presentation file and builds the list of URLs programmatically
  from that.

  When `nil` is provided or when no presentation file is found for the given
  `hash`, it returns an empty list.
  """
  def get_slide_urls(hash_or_presentation_file)

  def get_slide_urls(nil), do: []

  def get_slide_urls(hash) when is_integer(hash), do: get_slide_urls(to_string(hash))

  def get_slide_urls(hash) when is_binary(hash) do
    case Repo.get_by(PresentationFile, hash: hash) do
      nil ->
        []

      presentation ->
        get_slide_urls(presentation)
    end
  end

  def get_slide_urls(%PresentationFile{} = presentation) do
    get_slide_urls(presentation.hash, presentation.length, presentation.slide_order)
  end

  @doc """
  Returns the URL of the first slide (thumbnail) for a given presentation.
  Returns nil if no presentation file or hash is provided.
  """
  def get_first_slide_url(nil), do: nil

  def get_first_slide_url(%PresentationFile{hash: nil}), do: nil
  def get_first_slide_url(%PresentationFile{length: nil}), do: nil
  def get_first_slide_url(%PresentationFile{length: 0}), do: nil

  def get_first_slide_url(%PresentationFile{hash: hash, length: length})
      when is_binary(hash) and length > 0 do
    config = Application.get_env(:claper, :presentations)

    case Keyword.fetch!(config, :storage) do
      "local" ->
        "/uploads/#{hash}/1.jpg"

      "s3" ->
        base_url = Keyword.fetch!(config, :s3_public_url)
        base_url <> "/presentations/#{hash}/1.jpg"

      storage ->
        raise "Unrecognised presentations storage value #{storage}"
    end
  end

  @doc """
  Returns a list of JPG slide URLs for a given presentation `hash` and
  `length`, optionally reordered by `slide_order`. See also `get_slide_urls/1`.
  """
  def get_slide_urls(hash, length, slide_order \\ nil)

  def get_slide_urls(nil, _, _), do: []

  def get_slide_urls(hash, length, slide_order) when is_binary(hash) and is_integer(length) do
    config = Application.get_env(:claper, :presentations)

    case Keyword.fetch!(config, :storage) do
      "local" ->
        for index <- slide_indexes(length, slide_order) do
          "/uploads/#{hash}/#{index}.jpg"
        end

      "s3" ->
        base_url = Keyword.fetch!(config, :s3_public_url)

        for index <- slide_indexes(length, slide_order) do
          base_url <> "/presentations/#{hash}/#{index}.jpg"
        end

      storage ->
        raise "Unrecognised presentations storage value #{storage}"
    end
  end

  @doc """
  Returns a list of thumbnail URLs for a given presentation.
  Thumbnails are smaller versions of slides stored in a 'thumbs' subdirectory.
  """
  def get_slide_thumbnail_urls(nil), do: []

  def get_slide_thumbnail_urls(%PresentationFile{hash: nil}), do: []
  def get_slide_thumbnail_urls(%PresentationFile{length: nil}), do: []
  def get_slide_thumbnail_urls(%PresentationFile{length: 0}), do: []

  def get_slide_thumbnail_urls(%PresentationFile{} = presentation) do
    get_slide_thumbnail_urls(presentation.hash, presentation.length, presentation.slide_order)
  end

  def get_slide_thumbnail_urls(hash, length, slide_order \\ nil)
      when is_binary(hash) and is_integer(length) do
    config = Application.get_env(:claper, :presentations)

    case Keyword.fetch!(config, :storage) do
      "local" ->
        for index <- slide_indexes(length, slide_order) do
          "/uploads/#{hash}/thumbs/#{index}.jpg"
        end

      "s3" ->
        base_url = Keyword.fetch!(config, :s3_public_url)

        for index <- slide_indexes(length, slide_order) do
          base_url <> "/presentations/#{hash}/thumbs/#{index}.jpg"
        end

      storage ->
        raise "Unrecognised presentations storage value #{storage}"
    end
  end

  # Display order as a list of 1-based original slide file indexes. A stored
  # `slide_order` is only honored when it matches the slide count, so a stale
  # order (e.g. from before a re-upload) falls back to the natural order.
  defp slide_indexes(count, slide_order)
       when is_list(slide_order) and length(slide_order) == count,
       do: slide_order

  defp slide_indexes(count, _slide_order), do: Enum.to_list(1..count//1)

  @doc """
  Returns true when a presentation has slides but no generated thumbnails.
  """
  def missing_slide_thumbnails?(nil), do: false

  def missing_slide_thumbnails?(%PresentationFile{hash: nil}), do: false
  def missing_slide_thumbnails?(%PresentationFile{length: nil}), do: false
  def missing_slide_thumbnails?(%PresentationFile{length: 0}), do: false

  def missing_slide_thumbnails?(%PresentationFile{hash: hash}) do
    not slide_thumbnails_available?(hash)
  end

  @doc """
  Creates a presentation_files.

  ## Examples

      iex> create_presentation_file(%{field: value})
      {:ok, %PresentationFile{}}

      iex> create_presentation_file(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_presentation_file(attrs \\ %{}) do
    %PresentationFile{}
    |> PresentationFile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a presentation_files.

  ## Examples

      iex> update_presentation_file(presentation_file, %{field: new_value})
      {:ok, %PresentationFile{}}

      iex> update_presentation_file(presentation_file, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_presentation_file(%PresentationFile{} = presentation_file, attrs) do
    presentation_file
    |> PresentationFile.changeset(attrs)
    |> Repo.update()
  end

  def subscribe(presentation_file_id) do
    Phoenix.PubSub.subscribe(Claper.PubSub, "presentation:#{presentation_file_id}")
  end

  alias Claper.Presentations.PresentationState

  @doc """
  Creates a presentation_state.

  ## Examples

      iex> create_presentation_state(%{field: value})
      {:ok, %PresentationState{}}

      iex> create_presentation_state(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_presentation_state(attrs \\ %{}) do
    %PresentationState{}
    |> PresentationState.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a presentation_state.

  ## Examples

      iex> update_presentation_state(presentation_state, %{field: new_value})
      {:ok, %PresentationState{}}

      iex> update_presentation_state(presentation_state, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_presentation_state(%PresentationState{} = presentation_state, attrs) do
    presentation_state
    |> PresentationState.changeset(attrs)
    |> validate_chat_settings_while_chat_off(presentation_state)
    |> Repo.update()
    |> broadcast(:state_updated)
  end

  # Who may write a message only means something while messages are on at all,
  # which is why the moderator's screen renders both toggles disabled then. The
  # same rule belongs here, so a push that skips the rendered control is refused
  # with an error instead of quietly rewriting the setting.
  @chat_audience_settings [:anonymous_chat_enabled, :authenticated_chat_only]

  defp validate_chat_settings_while_chat_off(changeset, presentation_state) do
    if chat_enabled?(changeset, presentation_state) do
      changeset
    else
      Enum.reduce(@chat_audience_settings, changeset, &refuse_change_while_chat_off/2)
    end
  end

  defp refuse_change_while_chat_off(field, changeset) do
    case Ecto.Changeset.fetch_change(changeset, field) do
      {:ok, _value} ->
        Ecto.Changeset.add_error(
          changeset,
          field,
          "can only be changed while messages are enabled"
        )

      :error ->
        changeset
    end
  end

  # The stored row decides, not the struct the caller happens to hold, unless
  # the very same update switches messages on.
  defp chat_enabled?(changeset, presentation_state) do
    case Ecto.Changeset.fetch_change(changeset, :chat_enabled) do
      {:ok, chat_enabled} ->
        chat_enabled

      :error ->
        from(ps in PresentationState,
          where: ps.id == ^presentation_state.id and ps.chat_enabled == true
        )
        |> Repo.exists?()
    end
  end

  @doc """
  Returns true when the event only accepts messages from authenticated users.

  Always reads the current state from the database, so a caller holding a
  presentation state loaded earlier cannot accept a message with a stale value
  after the moderator turned the setting on.

  ## Examples

      iex> authenticated_chat_only?(event_id)
      false

  """
  def authenticated_chat_only?(event_id) do
    from(ps in PresentationState,
      join: pf in PresentationFile,
      on: ps.presentation_file_id == pf.id,
      where: pf.event_id == ^event_id and ps.authenticated_chat_only == true
    )
    |> Repo.exists?()
  end

  @interaction_schemas [
    Claper.Polls.Poll,
    Claper.Forms.Form,
    Claper.Embeds.Embed,
    Claper.Quizzes.Quiz
  ]

  @doc """
  Moves the slide displayed at position `from` to position `to` (both 0-based
  display positions).

  Slide files are never renamed (a hash directory can be shared by duplicated
  events); instead the per-presentation `slide_order` permutation is updated.
  Interactions (polls, forms, embeds, quizzes) and the current presentation
  state position are remapped so they stay attached to their slide content.

  Returns `{:ok, presentation_file, presentation_state}` or
  `{:error, :invalid_position}`.
  """
  def reorder_slides(%PresentationFile{} = presentation_file, from, to)
      when is_integer(from) and is_integer(to) do
    count = presentation_file.length || 0

    if from == to or from < 0 or to < 0 or from >= count or to >= count do
      {:error, :invalid_position}
    else
      do_reorder_slides(presentation_file, from, to)
    end
  end

  defp do_reorder_slides(presentation_file, from, to) do
    {moved, rest} =
      presentation_file.length
      |> slide_indexes(presentation_file.slide_order)
      |> List.pop_at(from)

    new_order = List.insert_at(rest, to, moved)

    Repo.transaction(fn ->
      presentation_file =
        presentation_file
        |> PresentationFile.changeset(%{slide_order: new_order})
        |> Repo.update!()

      Enum.each(@interaction_schemas, fn schema ->
        remap_interaction_positions(schema, presentation_file.id, from, to)
      end)

      state = Repo.get_by(PresentationState, presentation_file_id: presentation_file.id)
      new_position = state && remap_position(state.position, from, to)
      position_changed = state && new_position != state.position

      state =
        if position_changed do
          state
          |> PresentationState.changeset(%{position: new_position})
          |> Repo.update!()
        else
          state
        end

      {presentation_file, state, position_changed}
    end)
    |> case do
      {:ok, {presentation_file, state, position_changed}} ->
        if position_changed, do: broadcast({:ok, state}, :state_updated)
        {:ok, presentation_file, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Shifts the `position` column of every interaction so it follows its slide
  # content. Interactions on the moved slide are parked at -1 first to avoid
  # colliding with the shifted range.
  defp remap_interaction_positions(schema, presentation_file_id, from, to) do
    base = from(i in schema, where: i.presentation_file_id == ^presentation_file_id)

    base |> where([i], i.position == ^from) |> Repo.update_all(set: [position: -1])

    if from < to do
      base
      |> where([i], i.position > ^from and i.position <= ^to)
      |> Repo.update_all(inc: [position: -1])
    else
      base
      |> where([i], i.position >= ^to and i.position < ^from)
      |> Repo.update_all(inc: [position: 1])
    end

    base |> where([i], i.position == -1) |> Repo.update_all(set: [position: to])
  end

  defp remap_position(nil, _from, _to), do: nil
  defp remap_position(position, from, to) when position == from, do: to

  defp remap_position(position, from, to) when from < to and position > from and position <= to,
    do: position - 1

  defp remap_position(position, from, to) when from > to and position >= to and position < from,
    do: position + 1

  defp remap_position(position, _from, _to), do: position

  defp broadcast({:error, _reason} = error, _state), do: error

  defp broadcast({:ok, state}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "presentation:#{state.presentation_file_id}",
      {event, state}
    )

    {:ok, state}
  end

  defp slide_thumbnails_available?(hash) when is_binary(hash) do
    config = Application.get_env(:claper, :presentations)

    case Keyword.fetch!(config, :storage) do
      "local" ->
        thumbnails_glob(hash)
        |> Path.wildcard()
        |> Enum.any?()

      "s3" ->
        ExAws.S3.list_objects(get_s3_bucket(), prefix: "presentations/#{hash}/thumbs/")
        |> ExAws.stream!()
        |> Enum.take(1)
        |> Enum.any?()

      storage ->
        raise "Unrecognised presentations storage value #{storage}"
    end
  rescue
    _ -> false
  end

  defp thumbnails_glob(hash) do
    Path.join([
      get_presentation_storage_dir(),
      "uploads",
      hash,
      "thumbs",
      "*.jpg"
    ])
  end

  defp get_presentation_storage_dir do
    Application.get_env(:claper, :storage_dir)
  end

  defp get_s3_bucket do
    Application.get_env(:claper, :presentations) |> Keyword.get(:s3_bucket)
  end
end
