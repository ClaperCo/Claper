defmodule Claper.Presentations do
  @moduledoc """
  The Presentations context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Presentations.PresentationFile
  alias Claper.Presentations.PresenterNote

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
        get_slide_urls(hash, presentation.length)
    end
  end

  def get_slide_urls(%PresentationFile{} = presentation) do
    get_slide_urls(presentation.hash, presentation.length)
  end

  @doc """
  Returns a list of JPG slide URLs for a given presentation `hash` and
  `length`. See also `get_slide_urls/1`.
  """
  def get_slide_urls(hash, length)

  def get_slide_urls(nil, _), do: []

  def get_slide_urls(hash, length) when is_binary(hash) and is_integer(length) do
    config = Application.get_env(:claper, :presentations)

    case Keyword.fetch!(config, :storage) do
      "local" ->
        for index <- 1..length do
          "/uploads/#{hash}/#{index}.jpg"
        end

      "s3" ->
        base_url = Keyword.fetch!(config, :s3_public_url)

        for index <- 1..length do
          base_url <> "/presentations/#{hash}/#{index}.jpg"
        end

      storage ->
        raise "Unrecognised presentations storage value #{storage}"
    end
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

  @doc """
  Inserts a slide image at the given 0-based position.
  Renumbers existing files, updates length, and shifts interaction positions.
  Returns {:ok, updated_presentation_file} or {:error, reason}.
  """
  def insert_slide(%PresentationFile{} = pf, insert_position, image_path) do
    storage_dir = Application.get_env(:claper, :storage_dir, "priv/static")
    old_dir = Path.join([storage_dir, "uploads", pf.hash])
    new_hash = "#{:erlang.phash2("#{pf.hash}-#{System.system_time(:second)}")}"
    new_dir = Path.join([storage_dir, "uploads", new_hash])

    # insert_position is 0-based: 0 means "at the beginning"
    # file_insert_index is 1-based file naming
    file_insert_index = insert_position + 1

    File.mkdir_p!(new_dir)

    try do
      # Copy files before the insertion point
      for i <- 1..(file_insert_index - 1), i >= 1 do
        File.cp!(Path.join(old_dir, "#{i}.jpg"), Path.join(new_dir, "#{i}.jpg"))
      end

      # Copy the new slide image
      File.cp!(image_path, Path.join(new_dir, "#{file_insert_index}.jpg"))

      # Copy files after the insertion point (shifted by 1)
      for i <- file_insert_index..pf.length do
        File.cp!(Path.join(old_dir, "#{i}.jpg"), Path.join(new_dir, "#{i + 1}.jpg"))
      end

      # Atomic DB updates
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.update(
          :presentation_file,
          PresentationFile.changeset(pf, %{hash: new_hash, length: pf.length + 1})
        )
        |> Ecto.Multi.run(:shift_polls, fn _repo, _changes ->
          shift_positions(Claper.Polls.Poll, :position, pf.id, insert_position)
        end)
        |> Ecto.Multi.run(:shift_forms, fn _repo, _changes ->
          shift_positions(Claper.Forms.Form, :position, pf.id, insert_position)
        end)
        |> Ecto.Multi.run(:shift_embeds, fn _repo, _changes ->
          shift_positions(Claper.Embeds.Embed, :position, pf.id, insert_position)
        end)
        |> Ecto.Multi.run(:shift_quizzes, fn _repo, _changes ->
          shift_positions(Claper.Quizzes.Quiz, :position, pf.id, insert_position)
        end)
        |> Ecto.Multi.run(:shift_notes, fn _repo, _changes ->
          shift_positions(PresenterNote, :slide_position, pf.id, insert_position)
        end)

      case Repo.transaction(multi) do
        {:ok, %{presentation_file: updated_pf}} ->
          File.rm_rf!(old_dir)
          {:ok, updated_pf}

        {:error, _step, changeset, _changes} ->
          File.rm_rf!(new_dir)
          {:error, changeset}
      end
    rescue
      e ->
        File.rm_rf!(new_dir)
        {:error, e}
    end
  end

  defp shift_positions(schema, field, presentation_file_id, insert_position) do
    from(s in schema,
      where: s.presentation_file_id == ^presentation_file_id and field(s, ^field) >= ^insert_position
    )
    |> Repo.update_all(inc: [{field, 1}])

    {:ok, :shifted}
  end

  @doc """
  Reorders slides according to the given order list.
  `new_order` is a list of 0-based old indices in the desired new order.
  E.g., [2, 0, 1] means: new slide 0 = old slide 2, new slide 1 = old slide 0, new slide 2 = old slide 1.
  """
  def reorder_slides(%PresentationFile{} = pf, new_order) when is_list(new_order) do
    expected = Enum.sort(0..(pf.length - 1) |> Enum.to_list())

    if Enum.sort(new_order) != expected do
      {:error, :invalid_order}
    else
      storage_dir = Application.get_env(:claper, :storage_dir, "priv/static")
      old_dir = Path.join([storage_dir, "uploads", pf.hash])
      new_hash = "#{:erlang.phash2("#{pf.hash}-#{System.system_time(:second)}")}"
      new_dir = Path.join([storage_dir, "uploads", new_hash])

      # Build mapping: old_position => new_position
      position_map =
        new_order
        |> Enum.with_index()
        |> Enum.map(fn {old_idx, new_idx} -> {old_idx, new_idx} end)
        |> Map.new()

      File.mkdir_p!(new_dir)

      try do
        # Copy files in new order
        for {old_idx, new_idx} <- position_map do
          File.cp!(
            Path.join(old_dir, "#{old_idx + 1}.jpg"),
            Path.join(new_dir, "#{new_idx + 1}.jpg")
          )
        end

        # Remap positions atomically
        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.update(
            :presentation_file,
            PresentationFile.changeset(pf, %{hash: new_hash})
          )
          |> Ecto.Multi.run(:remap_polls, fn _repo, _changes ->
            remap_positions(Claper.Polls.Poll, :position, pf.id, position_map)
          end)
          |> Ecto.Multi.run(:remap_forms, fn _repo, _changes ->
            remap_positions(Claper.Forms.Form, :position, pf.id, position_map)
          end)
          |> Ecto.Multi.run(:remap_embeds, fn _repo, _changes ->
            remap_positions(Claper.Embeds.Embed, :position, pf.id, position_map)
          end)
          |> Ecto.Multi.run(:remap_quizzes, fn _repo, _changes ->
            remap_positions(Claper.Quizzes.Quiz, :position, pf.id, position_map)
          end)
          |> Ecto.Multi.run(:remap_notes, fn _repo, _changes ->
            remap_positions(PresenterNote, :slide_position, pf.id, position_map)
          end)
          |> Ecto.Multi.run(:remap_state, fn _repo, _changes ->
            state = Repo.get_by(PresentationState, presentation_file_id: pf.id)

            if state && Map.has_key?(position_map, state.position) do
              state
              |> PresentationState.changeset(%{position: position_map[state.position]})
              |> Repo.update()
            else
              {:ok, state}
            end
          end)

        case Repo.transaction(multi) do
          {:ok, %{presentation_file: updated_pf}} ->
            File.rm_rf!(old_dir)
            {:ok, updated_pf}

          {:error, _step, changeset, _changes} ->
            File.rm_rf!(new_dir)
            {:error, changeset}
        end
      rescue
        e ->
          File.rm_rf!(new_dir)
          {:error, e}
      end
    end
  end

  defp remap_positions(schema, field, presentation_file_id, position_map) do
    # Pass 1: set all positions to negative temporaries to avoid collisions
    Enum.each(position_map, fn {old_pos, new_pos} ->
      from(s in schema,
        where: s.presentation_file_id == ^presentation_file_id and field(s, ^field) == ^old_pos
      )
      |> Repo.update_all(set: [{field, -(new_pos + 1)}])
    end)

    # Pass 2: flip all negative positions back to positive
    Enum.each(0..(map_size(position_map) - 1), fn new_pos ->
      neg_val = -(new_pos + 1)

      from(s in schema,
        where: s.presentation_file_id == ^presentation_file_id and field(s, ^field) == ^neg_val
      )
      |> Repo.update_all(set: [{field, new_pos}])
    end)

    {:ok, :remapped}
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
    |> Repo.update()
    |> broadcast(:state_updated)
  end

  @doc """
  Returns the content of the presenter note for a given slide position,
  or an empty string if no note exists.
  """
  def get_note_at_position(presentation_file_id, position) do
    case Repo.get_by(PresenterNote,
           presentation_file_id: presentation_file_id,
           slide_position: position
         ) do
      nil -> ""
      note -> note.content || ""
    end
  end

  @doc """
  Inserts or updates the presenter note for a given slide position.
  """
  def upsert_note(presentation_file_id, position, content) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %PresenterNote{}
    |> PresenterNote.changeset(%{
      presentation_file_id: presentation_file_id,
      slide_position: position,
      content: content
    })
    |> Repo.insert(
      on_conflict: [set: [content: content, updated_at: now]],
      conflict_target: [:presentation_file_id, :slide_position]
    )
  end

  defp broadcast({:error, _reason} = error, _state), do: error

  defp broadcast({:ok, state}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "presentation:#{state.presentation_file_id}",
      {event, state}
    )

    {:ok, state}
  end
end
