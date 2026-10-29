defmodule Claper.Events do
  @moduledoc """
  The Events context.

  An activity leader is a facilitator, a user invited to manage an event.
  """

  import Ecto.Query, warn: false

  alias Claper.{Accounts, Presentations, Repo}
  alias Claper.Events.{Event, ActivityLeader, EventNotifier}

  @default_page_size 5

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
  Gets a single active (not expired) event by UUID, or `nil`.

  ## Examples

      iex> get_event_with_uuid("123e4567-e89b-12d3-a456-426614174000")
      %Event{}

      iex> get_event_with_uuid("not-a-uuid")
      nil

  """
  def get_event_with_uuid(uuid) do
    now = DateTime.utc_now()

    case Ecto.UUID.cast(uuid) do
      {:ok, uuid} ->
        from(e in Event,
          where: e.uuid == ^uuid and (is_nil(e.expired_at) or e.expired_at > ^now)
        )
        |> Repo.one()

      :error ->
        nil
    end
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

  defp validate_unique_event(%Ecto.Changeset{changes: %{code: nil}} = changeset),
    do: {:ok, changeset}

  defp validate_unique_event(%Ecto.Changeset{changes: %{code: code} = _changes} = event) do
    case get_event_with_code(code) do
      %Event{} -> {:error, Ecto.Changeset.add_error(event, :code, "Already exists")}
      nil -> {:ok, event}
    end
  end

  defp validate_unique_event(%Ecto.Changeset{data: event} = changeset) do
    if active_after_save?(changeset) and code_used_by_other_active_event?(event.code, event.id) do
      {:error, Ecto.Changeset.add_error(changeset, :code, "Already exists")}
    else
      {:ok, changeset}
    end
  end

  # An ended event no longer holds its code, so it can keep a code reused by a newer event.
  defp active_after_save?(changeset) do
    case Ecto.Changeset.get_field(changeset, :expired_at) do
      nil -> true
      expired_at -> NaiveDateTime.after?(expired_at, NaiveDateTime.utc_now())
    end
  end

  defp code_used_by_other_active_event?(nil, _event_id), do: false

  defp code_used_by_other_active_event?(code, event_id) do
    now = NaiveDateTime.utc_now()

    from(e in Event,
      where: e.code == ^code and e.id != ^event_id,
      where: is_nil(e.expired_at) or e.expired_at > ^now
    )
    |> Repo.exists?()
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
  Terminates an event and emails its owner a recap (see
  `Claper.Events.EventNotifier.deliver_recap/2`).

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
        broadcast_terminated(event)
        EventNotifier.deliver_recap(event, :manual)
        {:ok, event}

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  @activity_write_interval_seconds 10 * 60

  @doc """
  Records that an attendee or facilitator is using an event, which keeps
  `terminate_inactive_events/1` from ending it.

  So that a whole audience joining at once doesn't write the event row for every
  attendee, a visit is only written when the last recorded one is older than
  10 minutes.

  ## Examples

      iex> record_event_activity(event)
      :ok

  """
  def record_event_activity(%Event{id: id, last_active_at: last_active_at}) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    stale_before = NaiveDateTime.add(now, -@activity_write_interval_seconds)

    if is_nil(last_active_at) or NaiveDateTime.before?(last_active_at, stale_before) do
      from(e in Event,
        where: e.id == ^id,
        where: is_nil(e.last_active_at) or e.last_active_at < ^stale_before
      )
      |> Repo.update_all(set: [last_active_at: now])
    end

    :ok
  end

  @doc """
  Terminates the events without an end date that have had no activity since
  `inactive_since`, so that new events can use their codes.

  An event's last activity is the latest of its last recorded visit (see
  `record_event_activity/1`), its last update and its start date. Events linked
  to an LTI resource are never terminated here: the LMS link to them would stop
  working.

  The owners of events that just became inactive get a recap email (see
  `Claper.Events.EventNotifier.deliver_recap/2`). Events inactive for over a day
  longer, which the first run after enabling it or after downtime ends all at once,
  end without one.

  Returns the number of terminated events. `preview_inactive_events/1` tells what
  it would do without changing anything.

  ## Examples

      iex> terminate_inactive_events(~N[2026-10-01 00:00:00])
      3

  """
  def terminate_inactive_events(%NaiveDateTime{} = inactive_since) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # updated_at is kept so that the returned events still tell their last activity.
    {count, events} =
      inactive_since
      |> inactive_events_query()
      |> select([e], e)
      |> Repo.update_all(set: [expired_at: now])

    for event <- events do
      broadcast_terminated(event)

      if just_became_inactive?(event, inactive_since),
        do: EventNotifier.deliver_recap(event, :inactivity)
    end

    count
  end

  @doc """
  Returns what `terminate_inactive_events/1` would do for `inactive_since`, without
  changing anything: how many events it would terminate, and how many recap emails
  it would send.

  ## Examples

      iex> preview_inactive_events(~N[2026-10-01 00:00:00])
      %{terminated: 3, recaps: 1}

  """
  def preview_inactive_events(%NaiveDateTime{} = inactive_since) do
    events = inactive_since |> inactive_events_query() |> Repo.all()

    %{
      terminated: length(events),
      recaps:
        Enum.count(events, fn event ->
          just_became_inactive?(event, inactive_since) and EventNotifier.recap?(event)
        end)
    }
  end

  defp inactive_events_query(inactive_since) do
    from(e in Event,
      as: :event,
      where: is_nil(e.expired_at),
      where:
        fragment("GREATEST(?, ?, ?)", e.last_active_at, e.updated_at, e.started_at) <
          type(^inactive_since, :naive_datetime),
      where:
        not exists(from(r in Lti13.Resources.Resource, where: r.event_id == parent_as(:event).id))
    )
  end

  defp just_became_inactive?(%Event{} = event, inactive_since) do
    last_activity =
      [event.last_active_at, event.updated_at, event.started_at]
      |> Enum.reject(&is_nil/1)
      |> Enum.max(NaiveDateTime)

    NaiveDateTime.after?(last_activity, NaiveDateTime.add(inactive_since, -1, :day))
  end

  defp broadcast_terminated(%Event{} = event) do
    broadcast_all_users({:updated, event})
    broadcast_event(event.uuid, {:event_terminated, event.uuid})
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
              presentation_file: [polls: [:poll_opts], forms: [], embeds: [], word_clouds: []]
            )}
         end)
         |> Ecto.Multi.run(:to_event, fn _repo, _changes ->
           {:ok,
            get_user_event!(user_id, to_event_uuid,
              presentation_file: [:polls, :forms, :embeds, :word_clouds]
            )}
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
         |> Ecto.Multi.run(:word_clouds, fn _repo,
                                            %{from_event: from_event, to_event: to_event} ->
           {:ok,
            from_event.presentation_file.word_clouds
            |> Enum.each(fn word_cloud ->
              if word_cloud.position < to_event.presentation_file.length do
                {:ok, imported} =
                  Claper.WordClouds.create_word_cloud(%{
                    title: word_cloud.title,
                    position: word_cloud.position,
                    enabled: false,
                    show_results: word_cloud.show_results,
                    max_entries: word_cloud.max_entries,
                    presentation_file_id: to_event.presentation_file.id
                  })

                if word_cloud.enabled do
                  :ok = Claper.Interactions.enable_interaction(imported)
                end
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
          quizzes: [quiz_questions: [:quiz_question_opts]],
          word_clouds: []
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
      |> Ecto.Multi.run(:word_clouds, fn _repo, changes ->
        duplicate_word_clouds(original, changes)
      end)

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
      |> Map.put(:name, duplicate_event_name(original.name))

    create_event(attrs)
  end

  @copy_suffix " (Copy)"
  @event_name_max_length 50

  defp duplicate_event_name(name) do
    max_base_length = @event_name_max_length - String.length(@copy_suffix)

    base =
      if String.length(name) > max_base_length,
        do: name |> String.slice(0, max_base_length) |> String.trim_trailing(),
        else: name

    base <> @copy_suffix
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

  # Only the settings are copied. The words, and the ones the presenter hid,
  # belong to the previous audience.
  defp duplicate_word_clouds(original, changes) do
    case get_in(original.presentation_file.word_clouds) do
      word_clouds when is_list(word_clouds) ->
        word_clouds =
          for word_cloud <- word_clouds do
            attrs =
              Map.from_struct(word_cloud)
              |> Map.drop([:id, :inserted_at, :updated_at, :hidden_words])
              |> Map.put(:presentation_file_id, changes.presentation_file.id)

            {:ok, word_cloud} = Claper.WordClouds.create_word_cloud(attrs)
            word_cloud
          end

        {:ok, word_clouds}

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
  Permanently deletes an event, every interaction linked to it and its
  uploaded slides.

  Polls, forms and embeds only have their presentation file reference
  nilified by the database, so they are deleted explicitly. Everything else
  (posts, reactions, votes, quizzes, word clouds, stats, transcriptions,
  facilitators...) cascades from the event or its presentation file.

  Slides are removed from storage once no other presentation file shares
  the same hash (duplicated events reuse the original slides).

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

      iex> delete_event(event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Event{} = event) do
    event = Repo.preload(event, :presentation_file)

    leaders =
      for %{email: email} <- get_activity_leaders_for_event(event.id),
          leader = Accounts.get_user_by_email(email),
          not is_nil(leader) do
        leader
      end

    with {:ok, event} <- Repo.transaction(fn -> purge_event(event) end) do
      clear_presentation_storage(event.presentation_file)
      broadcast_user_events(event.user_id, {:deleted, event})

      for leader <- leaders do
        broadcast_user_events(leader.id, {:deleted, event})
      end

      {:ok, event}
    end
  end

  defp purge_event(%Event{presentation_file: presentation_file} = event) do
    if presentation_file do
      for schema <- [Claper.Polls.Poll, Claper.Forms.Form, Claper.Embeds.Embed] do
        from(r in schema, where: r.presentation_file_id == ^presentation_file.id)
        |> Repo.delete_all()
      end
    end

    case Repo.delete(event) do
      {:ok, event} -> event
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp clear_presentation_storage(%Presentations.PresentationFile{hash: hash})
       when is_binary(hash) do
    if Presentations.get_presentation_files_by_hash(hash) == [] do
      Task.Supervisor.start_child(Claper.TaskSupervisor, fn ->
        Claper.Tasks.Converter.clear(hash)
      end)
    end

    :ok
  end

  defp clear_presentation_storage(_presentation_file), do: :ok

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

  def broadcast_user_events(nil, _message), do: :ok

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
