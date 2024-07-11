defmodule Claper.Events do
  @moduledoc """
  The Events context.

  An activity leader is a facilitator, a user invited to manage an event.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Events.{Event, ActivityLeader}

  @doc """
  Returns the list of events of a given user.

  ## Examples

      iex> list_events(123)
      [%Event{}, ...]

  """
  def list_events(user_id, preload \\ []) do
    from(e in Event, where: e.user_id == ^user_id, order_by: [desc: e.inserted_at])
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @doc """
  Returns the list of events managed by a given user email.

  ## Examples

      iex> list_managed_events_by("email@example.com")
      [%Event{}, ...]

  """
  def list_managed_events_by(email, preload \\ []) do
    from(a in ActivityLeader,
      join: u in Claper.Accounts.User,
      on: u.email == a.email,
      join: e in Event,
      on: e.id == a.event_id,
      where: a.email == ^email,
      order_by: [desc: e.expired_at],
      select: e
    )
    |> Repo.all()
    |> Repo.preload(preload)
  end

  def count_events_month(user_id) do
    # minus 30 days, calculated as seconds
    seconds = -30 * 24 * 3600
    last_month = DateTime.utc_now() |> DateTime.add(seconds, :second)

    from(e in Event,
      where:
        e.user_id == ^user_id and e.inserted_at <= ^DateTime.utc_now() and
          e.inserted_at >= ^last_month,
      order_by: [desc: e.id]
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!("123e4567-e89b-12d3-a456-426614174000")
      %Event{}

      iex> get_event!("123e4567-e89b-12d3-a456-4266141740111")
      ** (Ecto.NoResultsError)

  """
  def get_event!(id, preload \\ []),
    do: Repo.get_by!(Event, uuid: id) |> Repo.preload(preload)

  @doc """
  Gets a single managed event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_managed_event!(user, "123e4567-e89b-12d3-a456-426614174000")
      %Event{}

      iex> get_managed_event!(another_user, "123e4567-e89b-12d3-a456-426614174000")
      ** (Ecto.NoResultsError)

  """
  def get_managed_event!(current_user, id, preload \\ []) do
    event = Repo.get_by!(Event, uuid: id)

    is_leader =
      Claper.Events.is_leaded_by(current_user.email, event) || event.user_id == current_user.id

    if is_leader do
      event |> Repo.preload(preload)
    else
      raise Ecto.NoResultsError
    end
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
  Get a single event with the same code excluding a specific event.

  ## Examples

      iex> get_different_event_with_code("Hello", 123)
      %Event{}


  """
  def get_different_event_with_code(nil, _event_id), do: nil

  def get_different_event_with_code(code, event_id) do
    now = DateTime.utc_now()

    from(e in Event, where: e.code == ^code and e.id != ^event_id and e.expired_at > ^now)
    |> Repo.one()
  end

  @doc """
  Check if a user is a facilitator of a specific event.

  ## Examples

      iex> is_leaded_by("email@example.com", 123)
      true


  """
  def is_leaded_by(email, event) do
    from(a in ActivityLeader,
      join: u in Claper.Accounts.User,
      on: u.email == a.email,
      join: e in Event,
      on: e.id == a.event_id,
      where: a.email == ^email and e.id == ^event.id,
      order_by: [desc: e.expired_at]
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
        Repo.insert(event, returning: [:uuid])

      {:error, changeset} ->
        {:error, %{changeset | action: :insert}}
    end
  end

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
        Repo.update(event, returning: [:uuid])

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
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
        broadcast({:ok, event, event.uuid}, :event_terminated)

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
  Deletes a event.

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

      iex> delete_event(event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Event{} = event) do
    Repo.delete(event)
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

  alias Claper.Events.ActivityLeader

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
      left_join: u in Claper.Accounts.User,
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

  defp broadcast({:error, _reason} = error, _event), do: error

  defp broadcast({:ok, e, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, event_uuid}
    )

    {:ok, e}
  end
end
