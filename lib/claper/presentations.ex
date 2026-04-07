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
    new_hash = "#{:erlang.phash2("#{pf.hash}-#{System.system_time(:second)}")}"
    file_insert_index = insert_position + 1

    try do
      # Copy existing slides and insert the new one
      copy_slide_to_new_hash(image_path, new_hash, file_insert_index)

      if file_insert_index > 1 do
        for i <- 1..(file_insert_index - 1) do
          copy_slide_between_hashes(pf.hash, i, new_hash, i)
        end
      end

      if file_insert_index <= pf.length do
        for i <- file_insert_index..pf.length do
          copy_slide_between_hashes(pf.hash, i, new_hash, i + 1)
        end
      end

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
          clear_slide_hash(pf.hash)
          {:ok, updated_pf}

        {:error, _step, changeset, _changes} ->
          clear_slide_hash(new_hash)
          {:error, changeset}
      end
    rescue
      e ->
        clear_slide_hash(new_hash)
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
  Deletes a slide at the given 0-based position.
  Copies remaining files to a new hash, updates length, shifts interaction positions down,
  and deletes any interactions that were on the removed slide.
  """
  def delete_slide(%PresentationFile{length: length} = pf, delete_position) when length > 1 do
    new_hash = "#{:erlang.phash2("#{pf.hash}-#{System.system_time(:second)}")}"
    file_delete_index = delete_position + 1

    try do
      # Copy files before the deleted slide
      if file_delete_index > 1 do
        for i <- 1..(file_delete_index - 1) do
          copy_slide_between_hashes(pf.hash, i, new_hash, i)
        end
      end

      # Copy files after the deleted slide, shifted down by 1
      if file_delete_index < pf.length do
        for i <- (file_delete_index + 1)..pf.length do
          copy_slide_between_hashes(pf.hash, i, new_hash, i - 1)
        end
      end

      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.update(
          :presentation_file,
          PresentationFile.changeset(pf, %{hash: new_hash, length: pf.length - 1})
        )
        |> Ecto.Multi.run(:delete_polls, fn _repo, _changes ->
          delete_at_position(Claper.Polls.Poll, :position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:delete_forms, fn _repo, _changes ->
          delete_at_position(Claper.Forms.Form, :position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:delete_embeds, fn _repo, _changes ->
          delete_at_position(Claper.Embeds.Embed, :position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:delete_quizzes, fn _repo, _changes ->
          delete_at_position(Claper.Quizzes.Quiz, :position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:delete_notes, fn _repo, _changes ->
          delete_at_position(PresenterNote, :slide_position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:unshift_polls, fn _repo, _changes ->
          unshift_positions(Claper.Polls.Poll, :position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:unshift_forms, fn _repo, _changes ->
          unshift_positions(Claper.Forms.Form, :position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:unshift_embeds, fn _repo, _changes ->
          unshift_positions(Claper.Embeds.Embed, :position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:unshift_quizzes, fn _repo, _changes ->
          unshift_positions(Claper.Quizzes.Quiz, :position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:unshift_notes, fn _repo, _changes ->
          unshift_positions(PresenterNote, :slide_position, pf.id, delete_position)
        end)
        |> Ecto.Multi.run(:fix_state, fn _repo, _changes ->
          state = Repo.get_by(Claper.Presentations.PresentationState, presentation_file_id: pf.id)

          cond do
            is_nil(state) -> {:ok, nil}
            state.position == delete_position && pf.length > 1 ->
              new_pos = max(0, delete_position - 1)
              state
              |> Claper.Presentations.PresentationState.changeset(%{position: new_pos})
              |> Repo.update()
            state.position > delete_position ->
              state
              |> Claper.Presentations.PresentationState.changeset(%{position: state.position - 1})
              |> Repo.update()
            true -> {:ok, state}
          end
        end)

      case Repo.transaction(multi) do
        {:ok, %{presentation_file: updated_pf}} ->
          clear_slide_hash(pf.hash)
          {:ok, updated_pf}

        {:error, _step, changeset, _changes} ->
          clear_slide_hash(new_hash)
          {:error, changeset}
      end
    rescue
      e ->
        clear_slide_hash(new_hash)
        {:error, e}
    end
  end

  def delete_slide(_pf, _position), do: {:error, :cannot_delete_last_slide}

  defp delete_at_position(schema, field, presentation_file_id, position) do
    from(s in schema,
      where: s.presentation_file_id == ^presentation_file_id and field(s, ^field) == ^position
    )
    |> Repo.delete_all()

    {:ok, :deleted}
  end

  defp unshift_positions(schema, field, presentation_file_id, deleted_position) do
    from(s in schema,
      where: s.presentation_file_id == ^presentation_file_id and field(s, ^field) > ^deleted_position
    )
    |> Repo.update_all(inc: [{field, -1}])

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
      new_hash = "#{:erlang.phash2("#{pf.hash}-#{System.system_time(:second)}")}"

      position_map =
        new_order
        |> Enum.with_index()
        |> Map.new()

      try do
        for {old_idx, new_idx} <- position_map do
          copy_slide_between_hashes(pf.hash, old_idx + 1, new_hash, new_idx + 1)
        end

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
            state = Repo.get_by(Claper.Presentations.PresentationState, presentation_file_id: pf.id)

            if state && Map.has_key?(position_map, state.position) do
              state
              |> Claper.Presentations.PresentationState.changeset(%{position: position_map[state.position]})
              |> Repo.update()
            else
              {:ok, state}
            end
          end)

        case Repo.transaction(multi) do
          {:ok, %{presentation_file: updated_pf}} ->
            clear_slide_hash(pf.hash)
            {:ok, updated_pf}

          {:error, _step, changeset, _changes} ->
            clear_slide_hash(new_hash)
            {:error, changeset}
        end
      rescue
        e ->
          clear_slide_hash(new_hash)
          {:error, e}
      end
    end
  end

  defp remap_positions(schema, field, presentation_file_id, position_map) do
    Enum.each(position_map, fn {old_pos, new_pos} ->
      from(s in schema,
        where: s.presentation_file_id == ^presentation_file_id and field(s, ^field) == ^old_pos
      )
      |> Repo.update_all(set: [{field, -(new_pos + 1)}])
    end)

    Enum.each(0..(map_size(position_map) - 1), fn new_pos ->
      neg_val = -(new_pos + 1)

      from(s in schema,
        where: s.presentation_file_id == ^presentation_file_id and field(s, ^field) == ^neg_val
      )
      |> Repo.update_all(set: [{field, new_pos}])
    end)

    {:ok, :remapped}
  end

  # Storage-agnostic helpers for slide file operations

  defp presentation_storage do
    Application.get_env(:claper, :presentations) |> Keyword.get(:storage)
  end

  defp s3_bucket do
    Application.get_env(:claper, :presentations) |> Keyword.get(:s3_bucket)
  end

  defp copy_slide_to_new_hash(local_image_path, new_hash, dest_index) do
    case presentation_storage() do
      "local" ->
        storage_dir = Application.get_env(:claper, :storage_dir, "priv/static")
        new_dir = Path.join([storage_dir, "uploads", new_hash])
        File.mkdir_p!(new_dir)
        File.cp!(local_image_path, Path.join(new_dir, "#{dest_index}.jpg"))

      "s3" ->
        local_image_path
        |> ExAws.S3.Upload.stream_file()
        |> ExAws.S3.upload(s3_bucket(), "presentations/#{new_hash}/#{dest_index}.jpg", acl: "public-read")
        |> ExAws.request!()
    end
  end

  defp copy_slide_between_hashes(old_hash, old_index, new_hash, new_index) do
    case presentation_storage() do
      "local" ->
        storage_dir = Application.get_env(:claper, :storage_dir, "priv/static")
        old_path = Path.join([storage_dir, "uploads", old_hash, "#{old_index}.jpg"])
        new_dir = Path.join([storage_dir, "uploads", new_hash])
        File.mkdir_p!(new_dir)
        File.cp!(old_path, Path.join(new_dir, "#{new_index}.jpg"))

      "s3" ->
        ExAws.S3.put_object_copy(
          s3_bucket(),
          "presentations/#{new_hash}/#{new_index}.jpg",
          s3_bucket(),
          "presentations/#{old_hash}/#{old_index}.jpg"
        )
        |> ExAws.request!()
    end
  end

  defp clear_slide_hash(hash) do
    case presentation_storage() do
      "local" ->
        storage_dir = Application.get_env(:claper, :storage_dir, "priv/static")
        File.rm_rf!(Path.join([storage_dir, "uploads", hash]))

      "s3" ->
        stream =
          ExAws.S3.list_objects(s3_bucket(), prefix: "presentations/#{hash}")
          |> ExAws.stream!()
          |> Stream.map(& &1.key)

        ExAws.S3.delete_all_objects(s3_bucket(), stream) |> ExAws.request()
    end
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
