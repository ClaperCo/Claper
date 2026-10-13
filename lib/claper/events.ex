defmodule Claper.Events do
  @moduledoc """
  The Events context.

  An activity leader is a facilitator, a user invited to manage an event.
  """

  import Ecto.Query, warn: false

  alias Claper.{Accounts, Presentations, Repo}
  alias Claper.Events.{Event, ActivityLeader, Folder}

  @default_page_size 5

  @doc """
  Returns the folders of a given user, ordered by name.
  """
  def list_folders(user_id) do
    from(f in Folder, where: f.user_id == ^user_id, order_by: [asc: f.name])
    |> Repo.all()
  end

  @doc """
  Returns the direct subfolders of a folder (`nil` for the top level), ordered by name.
  """
  def list_child_folders(user_id, nil) do
    from(f in Folder, where: f.user_id == ^user_id and is_nil(f.parent_id), order_by: f.name)
    |> Repo.all()
  end

  def list_child_folders(user_id, parent_id) do
    from(f in Folder,
      where: f.user_id == ^user_id and f.parent_id == ^parent_id,
      order_by: f.name
    )
    |> Repo.all()
  end

  @doc """
  Gets a folder of a given user. Raises `Ecto.NoResultsError` if the user does not own it.
  """
  def get_user_folder!(user_id, id), do: Repo.get_by!(Folder, id: id, user_id: user_id)

  @doc """
  Gets a folder of a given user by its public uuid. Raises `Ecto.NoResultsError` if the user
  does not own it.
  """
  def get_user_folder_by_uuid!(user_id, uuid),
    do: Repo.get_by!(Folder, uuid: uuid, user_id: user_id)

  @doc """
  Gets a folder of a given user by the names from the top level down, e.g.
  `["Courses", "Elixir"]`. Names are unique among siblings, so the path is unambiguous.
  Raises `Ecto.NoResultsError` if there is no such folder.
  """
  def get_user_folder_by_path!(_user_id, []), do: raise(Ecto.NoResultsError, queryable: Folder)

  def get_user_folder_by_path!(user_id, names) do
    Enum.reduce(names, nil, fn name, parent ->
      query = from(f in Folder, where: f.user_id == ^user_id and f.name == ^name)

      query =
        if parent,
          do: where(query, [f], f.parent_id == ^parent.id),
          else: where(query, [f], is_nil(f.parent_id))

      Repo.one!(query)
    end)
  end

  @doc """
  Returns the folder and its ancestors, root first.
  """
  def folder_path(%Folder{} = folder), do: do_folder_path(folder, [folder])

  defp do_folder_path(%Folder{parent_id: nil}, path), do: path

  defp do_folder_path(%Folder{parent_id: parent_id}, path) do
    parent = Repo.get!(Folder, parent_id)
    do_folder_path(parent, [parent | path])
  end

  @doc """
  Returns `{label, id}` pairs for all folders of a user, labelled with their path
  (e.g. "Courses / Elixir"). Pass `exclude: folder` to leave out a folder and its
  descendants, as when choosing a new parent for it.
  """
  def folder_options(user_id, opts \\ []) do
    folders = list_folders(user_id)
    by_id = Map.new(folders, &{&1.id, &1})
    excluded = opts[:exclude]

    folders
    |> Enum.map(&{&1, path_of(&1, by_id)})
    |> Enum.reject(fn {_, path} -> excluded && Enum.any?(path, &(&1.id == excluded.id)) end)
    |> Enum.map(fn {folder, path} -> {Enum.map_join(path, " / ", & &1.name), folder.id} end)
    |> Enum.sort()
  end

  @doc """
  Returns the events directly inside a folder of a given user.
  """
  def list_folder_events(user_id, folder_id, preload \\ []) do
    from(e in Event, where: e.user_id == ^user_id and e.folder_id == ^folder_id)
    |> Repo.all()
    |> Repo.preload(preload)
  end

  defp path_of(%Folder{parent_id: nil} = folder, _by_id), do: [folder]

  defp path_of(%Folder{parent_id: parent_id} = folder, by_id),
    do: path_of(Map.fetch!(by_id, parent_id), by_id) ++ [folder]

  def create_folder(user_id, attrs) do
    %Folder{}
    |> Folder.changeset(Map.put(attrs, "user_id", user_id))
    |> validate_parent(user_id)
    |> Repo.insert()
  end

  def update_folder(%Folder{} = folder, attrs) do
    folder
    |> Folder.changeset(Map.delete(attrs, "user_id"))
    |> validate_parent(folder.user_id)
    |> Repo.update()
  end

  # The parent must belong to the same user, and a folder can't be moved into itself
  # or one of its descendants.
  defp validate_parent(changeset, user_id) do
    case Ecto.Changeset.get_change(changeset, :parent_id) do
      nil ->
        changeset

      parent_id ->
        parent = Repo.get_by(Folder, id: parent_id, user_id: user_id)
        folder_id = changeset.data.id

        if parent && !(folder_id && folder_id in Enum.map(folder_path(parent), & &1.id)) do
          changeset
        else
          Ecto.Changeset.add_error(changeset, :parent_id, "is invalid")
        end
    end
  end

  @doc """
  Deletes a folder. Its subfolders move up to the parent folder.

  The events directly inside it are kept and become unfiled, or are deleted with
  `delete_events: true`.

  Returns `{:ok, %{folder: folder, deleted_events: events}}`, with the deleted events'
  presentation file preloaded so the caller can clean up files, or
  `{:error, :name_conflict}` if a subfolder would clash with a sibling name one level up.
  """
  def delete_folder(%Folder{} = folder, opts \\ []) do
    events =
      if opts[:delete_events],
        do: list_folder_events(folder.user_id, folder.id, [:presentation_file]),
        else: []

    Repo.transaction(fn ->
      # First, as this is the step that can fail on a name clash
      from(f in Folder, where: f.parent_id == ^folder.id)
      |> Repo.update_all(set: [parent_id: folder.parent_id])

      for event <- events, do: {:ok, _} = delete_event(event)

      from(e in Event, where: e.folder_id == ^folder.id)
      |> Repo.update_all(set: [folder_id: nil])

      %{folder: Repo.delete!(folder), deleted_events: events}
    end)
  rescue
    e in Postgrex.Error ->
      if e.postgres.code == :unique_violation,
        do: {:error, :name_conflict},
        else: reraise(e, __STACKTRACE__)
  end

  @doc """
  Returns the list of events of a given user.

  ## Examples

      iex> list_events(123)
      [%Event{}, ...]

  """
  def list_events(user_id, preload \\ []) do
    from(e in Event, where: e.user_id == ^user_id, order_by: [desc: e.id])
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @doc """
  Returns a paginated list of events for a given user.

  ## Examples

      iex> paginate_events(123, %{page: 1, page_size: 10})
      {[%Event{}, ...], total_count, total_pages}

  """
  def paginate_events(user_id, params \\ %{}, preload \\ []) do
    page = Map.get(params, "page", 1)
    page_size = Map.get(params, "page_size", @default_page_size)

    query =
      from(e in Event,
        where: e.user_id == ^user_id,
        order_by: [desc: e.id]
      )

    Repo.paginate(query, page: page, page_size: page_size, preload: preload)
  end

  @doc """
  Returns the list of not expired events for a given user.

  ## Examples

      iex> list_not_expired_events(123)
      [%Event{}, ...]

  """
  def list_not_expired_events(user_id, preload \\ []) do
    from(e in Event,
      where: e.user_id == ^user_id and is_nil(e.expired_at),
      order_by: [desc: e.id]
    )
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @doc """
  Returns a paginated list of not expired events for a given user.

  ## Examples

      iex> paginate_not_expired_events(123, %{page: 1, page_size: 10})
      {[%Event{}, ...], total_count, total_pages}

  """
  def paginate_not_expired_events(user_id, params \\ %{}, preload \\ []) do
    page = Map.get(params, "page", 1)
    page_size = Map.get(params, "page_size", @default_page_size)
    search = Map.get(params, "search", nil)

    query =
      from(e in Event,
        where: e.user_id == ^user_id and is_nil(e.expired_at),
        order_by: [desc: e.id]
      )
      |> apply_search(search)
      |> apply_folder(params)

    Repo.paginate(query, page: page, page_size: page_size, preload: preload)
  end

  @doc """
  Returns the list of expired events for a given user.

  ## Examples

      iex> list_expired_events(123)
      [%Event{}, ...]

  """
  def list_expired_events(user_id, preload \\ []) do
    from(e in Event,
      where: e.user_id == ^user_id and not is_nil(e.expired_at),
      order_by: [desc: e.expired_at]
    )
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @doc """
  Returns a paginated list of expired events for a given user.

  ## Examples

      iex> paginate_expired_events(123, %{page: 1, page_size: 10})
      {[%Event{}, ...], total_count, total_pages}

  """
  def paginate_expired_events(user_id, params \\ %{}, preload \\ []) do
    page = Map.get(params, "page", 1)
    page_size = Map.get(params, "page_size", @default_page_size)
    search = Map.get(params, "search", nil)

    query =
      from(e in Event,
        where: e.user_id == ^user_id and not is_nil(e.expired_at),
        order_by: [desc: e.expired_at]
      )
      |> apply_search(search)
      |> apply_folder(params)

    Repo.paginate(query, page: page, page_size: page_size, preload: preload)
  end

  @doc """
  Returns the list of events managed by a given user email.

  ## Examples

      iex> list_managed_events_by("email@example.com")
      [%Event{}, ...]

  """
  def list_managed_events_by(email, preload \\ []) do
    from(a in ActivityLeader,
      join: u in Accounts.User,
      on: u.email == a.email,
      join: e in Event,
      on: e.id == a.event_id,
      where: a.email == ^email,
      order_by: [desc: e.expired_at, desc: e.id],
      select: e
    )
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @doc """
  Returns a paginated list of events managed by a given user email.

  ## Examples

      iex> paginate_managed_events_by("email@example.com", %{page: 1, page_size: 10})
      {[%Event{}, ...], total_count, total_pages}

  """
  def paginate_managed_events_by(email, params \\ %{}, preload \\ []) do
    page = Map.get(params, "page", 1)
    page_size = Map.get(params, "page_size", @default_page_size)
    search = Map.get(params, "search", nil)

    query =
      from(a in ActivityLeader,
        join: u in Accounts.User,
        on: u.email == a.email,
        join: e in Event,
        on: e.id == a.event_id,
        where: a.email == ^email,
        order_by: [desc: e.expired_at, desc: e.id],
        select: e
      )
      |> apply_search_managed(search)

    Repo.paginate(query, page: page, page_size: page_size, preload: preload)
  end

  def count_managed_events_by(email) do
    from(a in ActivityLeader,
      join: u in Accounts.User,
      on: u.email == a.email,
      join: e in Event,
      on: e.id == a.event_id,
      where: a.email == ^email,
      select: e
    )
    |> Repo.aggregate(:count, :id)
  end

  def count_expired_events(user_id) do
    from(e in Event,
      where: e.user_id == ^user_id and not is_nil(e.expired_at)
    )
    |> Repo.aggregate(:count, :id)
  end

  defp apply_search(query, nil), do: query
  defp apply_search(query, ""), do: query

  defp apply_search(query, search) when is_binary(search) do
    search_term = "%#{search}%"

    from(e in query,
      where: ilike(e.name, ^search_term) or ilike(e.code, ^search_term)
    )
  end

  # No "folder_id" key: all events. `nil`: top level only. An id: that folder only.
  defp apply_folder(query, params) do
    case Map.fetch(params, "folder_id") do
      :error -> query
      {:ok, nil} -> from(e in query, where: is_nil(e.folder_id))
      {:ok, folder_id} -> from(e in query, where: e.folder_id == ^folder_id)
    end
  end

  defp apply_search_managed(query, nil), do: query
  defp apply_search_managed(query, ""), do: query

  defp apply_search_managed(query, search) when is_binary(search) do
    search_term = "%#{search}%"

    from([a, u, e] in query,
      where: ilike(e.name, ^search_term) or ilike(e.code, ^search_term)
    )
  end

  def count_events_month(user_id) do
    # minus 30 days, calculated as seconds
    seconds = -30 * 24 * 3600
    last_month = DateTime.utc_now() |> DateTime.add(seconds, :second)

    from(e in Event,
      where:
        e.user_id == ^user_id and e.inserted_at <= ^DateTime.utc_now() and
          e.inserted_at >= ^last_month
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a single event by serial ID or UUID.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(123)
      %Event{}

      iex> get_event!("123e4567-e89b-12d3-a456-426614174000")
      %Event{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)

      iex> get_event!("123e4567-e89b-12d3-a456-4266141740111")
      ** (Ecto.NoResultsError)

  """
  def get_event!(id_or_uuid, preload \\ [])

  def get_event!(
        <<_::bytes-8, "-", _::bytes-4, "-", _::bytes-4, "-", _::bytes-4, "-", _::bytes-12>> =
          uuid,
        preload
      ),
      do: Repo.get_by!(Event, uuid: uuid) |> Repo.preload(preload)

  def get_event!(id, preload),
    do: Repo.get!(Event, id) |> Repo.preload(preload)

  @doc """
  Gets a single managed event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_managed_event!(user, "123e4567-e89b-12d3-a456-426614174000")
      %Event{}

      iex> get_managed_event!(another_user, "123e4567-e89b-12d3-a456-426614174000")
      ** (Ecto.NoResultsError)

  """
  def get_managed_event!(user, uuid, preload \\ []) do
    from(
      e in Event,
      join: u in Accounts.User,
      on: e.user_id == u.id,
      left_join: a in ActivityLeader,
      on: e.id == a.event_id,
      where: e.uuid == ^uuid and (u.id == ^user.id or a.email == ^user.email),
      distinct: true,
      select: e
    )
    |> Repo.one!()
    |> Repo.preload(preload)
  end

  @doc """
  Gets a single user's event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_user_event!(user, "123e4567-e89b-12d3-a456-426614174000")
      %Event{}

      iex> get_user_event!(another_user, "123e4567-e89b-12d3-a456-426614174000")
      ** (Ecto.NoResultsError)

  """
  def get_user_event!(user_id, id, preload \\ []),
    do: Repo.get_by!(Event, uuid: id, user_id: user_id) |> Repo.preload(preload)

  @doc """
  Gets a single event by code.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event_with_code!("Hello")
      %Event{}

      iex> get_event_with_code!("Old event")
      ** (Ecto.NoResultsError)

  """
  def get_event_with_code!(code, preload \\ []) do
    now = NaiveDateTime.utc_now()

    from(e in Event, where: e.code == ^code and (is_nil(e.expired_at) or e.expired_at > ^now))
    |> Repo.one!()
    |> Repo.preload(preload)
  end

  def get_event_with_code(code, preload \\ []) do
    now = DateTime.utc_now()

    from(e in Event, where: e.code == ^code and (is_nil(e.expired_at) or e.expired_at > ^now))
    |> Repo.one()
    |> Repo.preload(preload)
  end

  @doc """
  Check if a user is a facilitator of a specific event.

  ## Examples

      iex> led_by?("email@example.com", 123)
      true

  """
  def led_by?(email, event) do
    from(a in ActivityLeader,
      join: u in Accounts.User,
      on: u.email == a.email,
      join: e in Event,
      on: e.id == a.event_id,
      where: a.email == ^email and e.id == ^event.id
    )
    |> Repo.exists?()
  end

  @doc """
  Creates a event.

  ## Examples

      iex> create_event(%{field: value})
      {:ok, %Event{}}

      iex> create_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(attrs) do
    %Event{}
    |> Event.create_changeset(attrs)
    |> validate_folder_owner()
    |> validate_unique_event()
    |> case do
      {:ok, event} ->
        with {:ok, event} <- Repo.insert(event, returning: [:uuid]) do
          broadcast_all_users({:created, event})
          {:ok, event}
        end

      {:error, changeset} ->
        {:error, %{changeset | action: :insert}}
    end
  end

  # A folder can only hold events of its own user
  defp validate_folder_owner(changeset) do
    with folder_id when not is_nil(folder_id) <- Ecto.Changeset.get_change(changeset, :folder_id),
         user_id <- Ecto.Changeset.get_field(changeset, :user_id),
         false <-
           Repo.exists?(from f in Folder, where: f.id == ^folder_id and f.user_id == ^user_id) do
      Ecto.Changeset.add_error(changeset, :folder_id, "is invalid")
    else
      _ -> changeset
    end
  end

  defp validate_unique_event(%Ecto.Changeset{changes: %{code: nil}} = changeset),
    do: {:ok, changeset}

  defp validate_unique_event(%Ecto.Changeset{changes: %{code: code} = _changes} = event) do
    case get_event_with_code(code) do
      %Event{} -> {:error, Ecto.Changeset.add_error(event, :code, "Already exists")}
      nil -> {:ok, event}
    end
  end

  defp validate_unique_event(%Ecto.Changeset{data: event} = changeset) do
    case get_different_event_with_code(event.code, event.id) do
      %Event{} -> {:error, Ecto.Changeset.add_error(changeset, :code, "Already exists")}
      nil -> {:ok, changeset}
    end
  end

  defp get_different_event_with_code(nil, _event_id), do: nil

  defp get_different_event_with_code(code, event_id) do
    now = DateTime.utc_now()

    from(e in Event, where: e.code == ^code and e.id != ^event_id and e.expired_at > ^now)
    |> Repo.one()
  end

  @doc """
  Updates an event.

  ## Examples

      iex> update_event(event, %{field: new_value})
      {:ok, %Event{}}

      iex> update_event(event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_event(%Event{} = event, attrs) do
    event
    |> Event.update_changeset(attrs)
    |> validate_folder_owner()
    |> validate_unique_event()
    |> case do
      {:ok, event} ->
        with {:ok, event} <- Repo.update(event, returning: [:uuid]) do
          broadcast_all_users({:updated, event})
          broadcast_deleted_leaders(attrs, event)

          {:ok, event}
        end

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  defp broadcast_deleted_leaders(attrs, event) do
    attrs
    |> Map.get("leaders", %{})
    |> Map.values()
    |> Enum.each(fn
      %{"delete" => "true", "email" => email} ->
        case Accounts.get_user_by_email(email) do
          nil -> :ok
          leader -> broadcast_user_events(leader.id, {:updated, event})
        end

      _ ->
        :ok
    end)
  end

  @doc """
  Terminates an event.

  ## Examples

      iex> terminate_event(event)
      {:ok, %Event{}}

  """
  def terminate_event(%Event{} = event) do
    event
    |> Event.update_changeset(%{expired_at: NaiveDateTime.utc_now()})
    |> Repo.update()
    |> case do
      {:ok, event} ->
        broadcast_all_users({:updated, event})
        broadcast_event(event.uuid, {:event_terminated, event.uuid})
        {:ok, event}

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Import interactions from another event

  ## Examples

      iex> import(user_id, from_event_uuid, to_event_uuid)
      {:ok, %Event{}}

      iex> import(user_id, from_event_uuid, to_event_uuid)
      {:error, %Ecto.Changeset{}}

  """
  def import(user_id, from_event_uuid, to_event_uuid) do
    case Ecto.Multi.new()
         |> Ecto.Multi.run(:from_event, fn _repo, _changes ->
           {:ok,
            get_user_event!(user_id, from_event_uuid,
              presentation_file: [polls: [:poll_opts], forms: [], embeds: []]
            )}
         end)
         |> Ecto.Multi.run(:to_event, fn _repo, _changes ->
           {:ok,
            get_user_event!(user_id, to_event_uuid, presentation_file: [:polls, :forms, :embeds])}
         end)
         |> Ecto.Multi.run(:polls, fn _repo, %{from_event: from_event, to_event: to_event} ->
           {:ok,
            from_event.presentation_file.polls
            |> Enum.each(fn poll ->
              if poll.position < to_event.presentation_file.length do
                Claper.Polls.create_poll(%{
                  title: poll.title,
                  position: poll.position,
                  enabled: poll.enabled,
                  multiple: poll.multiple,
                  poll_opts:
                    Enum.map(poll.poll_opts, fn opt ->
                      %{content: opt.content, vote_count: 0}
                    end),
                  presentation_file_id: to_event.presentation_file.id
                })
              end
            end)}
         end)
         |> Ecto.Multi.run(:forms, fn _repo, %{from_event: from_event, to_event: to_event} ->
           {:ok,
            from_event.presentation_file.forms
            |> Enum.each(fn form ->
              if form.position < to_event.presentation_file.length do
                Claper.Forms.create_form(%{
                  title: form.title,
                  position: form.position,
                  enabled: form.enabled,
                  fields:
                    Enum.map(form.fields, fn field ->
                      %{
                        name: field.name,
                        type: field.type
                      }
                    end),
                  presentation_file_id: to_event.presentation_file.id
                })
              end
            end)}
         end)
         |> Ecto.Multi.run(:embeds, fn _repo, %{from_event: from_event, to_event: to_event} ->
           {:ok,
            from_event.presentation_file.embeds
            |> Enum.each(fn embed ->
              if embed.position < to_event.presentation_file.length do
                Claper.Embeds.create_embed(%{
                  title: embed.title,
                  content: embed.content,
                  position: embed.position,
                  enabled: embed.enabled,
                  attendee_visibility: embed.attendee_visibility,
                  presentation_file_id: to_event.presentation_file.id
                })
              end
            end)}
         end)
         |> Repo.transaction() do
      {:ok, %{to_event: to_event}} -> {:ok, to_event}
    end
  end

  @doc """
  Duplicates an event.

  Raises `Ecto.NoResultsError` for invalid `user_id`-`event_uuid` combinations
  and returns an error tuple if any part of the transaction fails.

  ## Examples

      iex> duplicate(user_id, event_uuid)
      {:ok, %Event{}}

      iex> duplicate(user_id, event_uuid)
      {:error, %Ecto.Changeset{}}

      iex> duplicate(another_user_id, event_uuid)
      ** (Ecto.NoResultsError)

  """
  def duplicate_event(user_id, event_uuid) do
    original =
      get_user_event!(user_id, event_uuid,
        presentation_file: [
          presentation_state: [],
          polls: [:poll_opts],
          forms: [],
          embeds: [],
          quizzes: [quiz_questions: [:quiz_question_opts]]
        ]
      )

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:event, fn _repo, changes -> duplicate_event_attrs(original, changes) end)
      |> Ecto.Multi.run(:presentation_file, fn _repo, changes ->
        duplicate_presentation_file(original, changes)
      end)
      |> Ecto.Multi.run(:presentation_state, fn _repo, changes ->
        duplicate_presentation_state(original, changes)
      end)
      |> Ecto.Multi.run(:polls, fn _repo, changes -> duplicate_polls(original, changes) end)
      |> Ecto.Multi.run(:forms, fn _repo, changes -> duplicate_forms(original, changes) end)
      |> Ecto.Multi.run(:embeds, fn _repo, changes -> duplicate_embeds(original, changes) end)
      |> Ecto.Multi.run(:quizzes, fn _repo, changes -> duplicate_quizzes(original, changes) end)

    case Repo.transaction(multi) do
      {:ok, %{event: event}} -> {:ok, event}
      {:error, _operation, value, _changes} -> {:error, value}
    end
  end

  defp duplicate_event_attrs(original, _changes) do
    code =
      for _ <- 1..5,
          into: "",
          do: <<Enum.random(~c"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")>>

    attrs =
      Map.from_struct(original)
      |> Map.drop([:id, :inserted_at, :updated_at, :presentation_file, :expired_at])
      |> Map.put(:leaders, [])
      |> Map.put(:code, "#{code}")
      |> Map.put(:name, "#{original.name} (Copy)")

    create_event(attrs)
  end

  defp duplicate_presentation_file(original, changes) do
    case get_in(original.presentation_file) do
      %Presentations.PresentationFile{} = presentation_file ->
        attrs =
          Map.from_struct(presentation_file)
          |> Map.drop([:id, :inserted_at, :updated_at, :presentation_state])
          |> Map.put(:event_id, changes.event.id)

        Presentations.create_presentation_file(attrs)

      _ ->
        {:ok, nil}
    end
  end

  defp duplicate_presentation_state(original, changes) do
    case get_in(original.presentation_file.presentation_state) do
      %Presentations.PresentationState{} = presentation_state ->
        attrs =
          Map.from_struct(presentation_state)
          |> Map.drop([:id, :inserted_at, :updated_at])
          |> Map.put(:presentation_file_id, changes.presentation_file.id)
          |> Map.put(:position, 0)
          |> Map.put(:banned, [])

        Presentations.create_presentation_state(attrs)

      _ ->
        {:ok, nil}
    end
  end

  defp duplicate_polls(original, changes) do
    case get_in(original.presentation_file.polls) do
      polls when is_list(polls) ->
        polls =
          for poll <- polls do
            attrs =
              Map.from_struct(poll)
              |> Map.drop([:id, :inserted_at, :updated_at])
              |> Map.put(:presentation_file_id, changes.presentation_file.id)
              |> Map.put(:poll_opts, Enum.map(poll.poll_opts, &duplicate_poll_opt_attrs/1))

            {:ok, poll} = Claper.Polls.create_poll(attrs)
            poll
          end

        {:ok, polls}

      _ ->
        {:ok, nil}
    end
  end

  defp duplicate_poll_opt_attrs(opt) do
    Map.from_struct(opt)
    |> Map.drop([:id, :inserted_at, :updated_at, :vote_count])
  end

  defp duplicate_forms(original, changes) do
    case get_in(original.presentation_file.forms) do
      forms when is_list(forms) ->
        forms =
          for form <- forms do
            attrs =
              Map.from_struct(form)
              |> Map.drop([:id, :inserted_at, :updated_at])
              |> Map.put(:presentation_file_id, changes.presentation_file.id)
              |> Map.put(
                :fields,
                Enum.map(form.fields, &Map.from_struct(&1))
              )

            {:ok, form} = Claper.Forms.create_form(attrs)
            form
          end

        {:ok, forms}

      _ ->
        {:ok, nil}
    end
  end

  defp duplicate_embeds(original, changes) do
    case get_in(original.presentation_file.embeds) do
      embeds when is_list(embeds) ->
        embeds =
          for embed <- embeds do
            attrs =
              Map.from_struct(embed)
              |> Map.drop([:id, :inserted_at, :updated_at])
              |> Map.put(:presentation_file_id, changes.presentation_file.id)

            {:ok, embed} = Claper.Embeds.create_embed(attrs)
            embed
          end

        {:ok, embeds}

      _ ->
        {:ok, nil}
    end
  end

  defp duplicate_quizzes(original, changes) do
    case get_in(original.presentation_file.quizzes) do
      quizzes when is_list(quizzes) ->
        quizzes =
          for quiz <- quizzes do
            attrs =
              Map.from_struct(quiz)
              |> Map.drop([:id, :inserted_at, :updated_at])
              |> Map.put(:presentation_file_id, changes.presentation_file.id)
              |> Map.put(:quiz_questions, Enum.map(quiz.quiz_questions, &map_quiz_question/1))

            {:ok, quiz} = Claper.Quizzes.create_quiz(attrs)
            quiz
          end

        {:ok, quizzes}

      _ ->
        {:ok, nil}
    end
  end

  defp map_quiz_question(question) do
    Map.from_struct(question)
    |> Map.drop([:id, :inserted_at, :updated_at])
    |> Map.put(
      :quiz_question_opts,
      Enum.map(question.quiz_question_opts, &map_quiz_question_opt/1)
    )
  end

  defp map_quiz_question_opt(opt) do
    Map.from_struct(opt)
    |> Map.drop([:id, :inserted_at, :updated_at])
    |> Map.put(:response_count, 0)
  end

  @doc """
  Deletes a event.

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

      iex> delete_event(event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Event{} = event) do
    leaders =
      for %{email: email} <- get_activity_leaders_for_event(event.id),
          leader = Accounts.get_user_by_email(email),
          not is_nil(leader) do
        leader
      end

    with {:ok, event} <- Repo.delete(event) do
      broadcast_user_events(event.user_id, {:deleted, event})

      for leader <- leaders do
        broadcast_user_events(leader.id, {:deleted, event})
      end

      {:ok, event}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.

  ## Examples

      iex> change_event(event)
      %Ecto.Changeset{data: %Event{}}

  """
  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  @doc """
  Creates a activity leader.

  ## Examples

      iex> create_activity_leader(%{field: value})
      {:ok, %ActivityLeader{}}

      iex> create_activity_leader(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_activity_leader(attrs) do
    %ActivityLeader{}
    |> ActivityLeader.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single facilitator.

  Raises `Ecto.NoResultsError` if the Activity leader does not exist.

  ## Examples

      iex> get_activity_leader!(123)
      %ActivityLeader{}

      iex> get_activity_leader!(456)
      ** (Ecto.NoResultsError)

  """
  def get_activity_leader!(id), do: Repo.get!(ActivityLeader, id)

  @doc """
  Gets all facilitators for a given event.

  ## Examples

      iex> get_activity_leaders_for_event!(event)
      [%ActivityLeader{}, ...]

  """
  def get_activity_leaders_for_event(event_id) do
    from(a in ActivityLeader,
      left_join: u in Accounts.User,
      on: u.email == a.email,
      where: a.event_id == ^event_id,
      select: %{a | user_id: u.id}
    )
    |> Repo.all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking facilitator changes.

  ## Examples

      iex> change_activity_leader(activity_leader)
      %Ecto.Changeset{data: %ActivityLeader{}}

  """
  def change_activity_leader(%ActivityLeader{} = activity_leader, attrs \\ %{}) do
    ActivityLeader.changeset(activity_leader, attrs)
  end

  @doc """
  Subscribes to an event's public `Phoenix.PubSub` topic.

  The broadcasted messages match the pattern:

    * {:terminated, event_uuid}

  """
  def subscribe_event(event_uuid) when is_binary(event_uuid) do
    Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{event_uuid}")
  end

  defp broadcast_event(event_uuid, message) when is_binary(event_uuid) do
    Phoenix.PubSub.broadcast(Claper.PubSub, "event:#{event_uuid}", message)
  end

  @doc """
  Subscribes to a user's events private `Phoenix.PubSub` topic.

  The broadcasted messages match the pattern:

    * {:created, %Event{}}
    * {:updated, %Event{}}
    * {:deleted, %Event{}}

  """
  def subscribe_user_events(user_id) when is_integer(user_id) do
    Phoenix.PubSub.subscribe(Claper.PubSub, "user:#{user_id}:events")
  end

  def broadcast_user_events(user_id, message) when is_integer(user_id) do
    Phoenix.PubSub.broadcast(Claper.PubSub, "user:#{user_id}:events", message)
  end

  defp broadcast_all_users({_type, %Event{} = event} = message, _opts \\ []) do
    event = Repo.preload(event, [:leaders])
    broadcast_user_events(event.user_id, message)

    for %{email: leader_email} <- event.leaders,
        leader = Accounts.get_user_by_email(leader_email),
        not is_nil(leader) do
      broadcast_user_events(leader.id, message)
    end
  end
end
