defmodule Claper.Scales do
  @moduledoc """
  The Scales context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Scales.Scale
  alias Claper.Scales.ScaleResponse

  @doc """
  Returns the list of scales for a given presentation file.

  ## Examples

      iex> list_scales(123)
      [%Scale{}, ...]

  """
  def list_scales(presentation_file_id) do
    from(s in Scale,
      where: s.presentation_file_id == ^presentation_file_id,
      order_by: [asc: s.id, asc: s.position]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of scales for a given presentation file and a given position.

  ## Examples

      iex> list_scales_at_position(123, 0)
      [%Scale{}, ...]

  """
  def list_scales_at_position(presentation_file_id, position) do
    from(s in Scale,
      where: s.presentation_file_id == ^presentation_file_id and s.position == ^position,
      order_by: [asc: s.id]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single scale.

  Raises `Ecto.NoResultsError` if the Scale does not exist.

  ## Examples

      iex> get_scale!(123)
      %Scale{}

      iex> get_scale!(456)
      ** (Ecto.NoResultsError)

  """
  def get_scale!(id, preload \\ []), do: Repo.get!(Scale, id) |> Repo.preload(preload)

  @doc """
  Gets a single scale scoped to the given event.

  Returns `nil` if the scale does not exist or does not belong to the event.
  """
  def get_scale_for_event(id, event_id, preload \\ []) do
    from(s in Scale,
      join: pf in assoc(s, :presentation_file),
      where: s.id == ^id and pf.event_id == ^event_id
    )
    |> Repo.one()
    |> case do
      nil -> nil
      scale -> Repo.preload(scale, preload)
    end
  end

  @doc """
  Gets the enabled scale for a given position.

  ## Examples

      iex> get_scale_current_position(123, 0)
      %Scale{}

  """
  def get_scale_current_position(presentation_file_id, position) do
    from(s in Scale,
      where:
        s.position == ^position and s.presentation_file_id == ^presentation_file_id and
          s.enabled == true
    )
    |> Repo.one()
  end

  @doc """
  Creates a scale.

  ## Examples

      iex> create_scale(%{field: value})
      {:ok, %Scale{}}

      iex> create_scale(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_scale(attrs \\ %{}) do
    %Scale{}
    |> Scale.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, scale} ->
        scale = Repo.preload(scale, presentation_file: :event)
        broadcast({:ok, scale, scale.presentation_file.event.uuid}, :scale_created)

      {:error, changeset} ->
        {:error, %{changeset | action: :insert}}
    end
  end

  @doc """
  Updates a scale.

  The changes apply to the stored scale, not to the struct passed in. Once the
  scale has responses its range is locked, see `Claper.Scales.Scale.changeset/3`.
  The row lock keeps a response from slipping in while this is checked.

  ## Examples

      iex> update_scale("123e4567-e89b-12d3-a456-426614174000", scale, %{field: new_value})
      {:ok, %Scale{}}

      iex> update_scale("123e4567-e89b-12d3-a456-426614174000", scale, %{min_value: 0})
      {:error, %Ecto.Changeset{}}

  """
  def update_scale(event_uuid, %Scale{id: id}, attrs) do
    Repo.transaction(fn ->
      scale = from(s in Scale, where: s.id == ^id, lock: "FOR UPDATE") |> Repo.one!()

      scale
      |> Scale.changeset(attrs, answered: answered?(scale))
      |> Repo.update()
      |> case do
        {:ok, scale} -> scale
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, scale} ->
        broadcast({:ok, scale, event_uuid}, :scale_updated)

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Deletes a scale together with its responses.

  ## Examples

      iex> delete_scale("123e4567-e89b-12d3-a456-426614174000", scale)
      {:ok, %Scale{}}

  """
  def delete_scale(event_uuid, %Scale{} = scale) do
    {:ok, scale} = Repo.delete(scale)
    broadcast({:ok, scale, event_uuid}, :scale_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking scale changes.

  ## Examples

      iex> change_scale(scale)
      %Ecto.Changeset{data: %Scale{}}

  """
  def change_scale(%Scale{} = scale, attrs \\ %{}, opts \\ []) do
    Scale.changeset(scale, attrs, opts)
  end

  def disable_all(presentation_file_id, position) do
    from(s in Scale,
      where: s.presentation_file_id == ^presentation_file_id and s.position == ^position
    )
    |> Repo.update_all(set: [enabled: false])
  end

  def set_enabled(id) do
    get_scale!(id)
    |> Ecto.Changeset.change(enabled: true)
    |> Repo.update()
  end

  def set_disabled(id) do
    get_scale!(id)
    |> Ecto.Changeset.change(enabled: false)
    |> Repo.update()
  end

  @doc """
  Returns true when at least one attendee has answered the scale.
  """
  def answered?(%Scale{id: nil}), do: false

  def answered?(%Scale{id: id}),
    do: Repo.exists?(from(r in ScaleResponse, where: r.scale_id == ^id))

  @doc """
  Records an attendee's answer to a scale.

  The scale is loaded again and has to be enabled and to belong to the event,
  since the attendee's copy can be stale and the value comes from the client. The identity
  is a user id for a signed-in attendee and the attendee identifier otherwise.

  ## Examples

      iex> submit_response(event_uuid, scale, attendee_identifier, "7")
      {:ok, %ScaleResponse{}}

      iex> submit_response(event_uuid, scale, attendee_identifier, "70")
      {:error, %Ecto.Changeset{}}

      iex> submit_response(event_uuid, closed_scale, attendee_identifier, "7")
      {:error, :not_an_open_scale}

  """
  def submit_response(event_uuid, %Scale{id: id}, identity, value) do
    Repo.transaction(fn ->
      case lock_open_scale(event_uuid, id) do
        nil -> Repo.rollback(:not_an_open_scale)
        scale -> {scale, insert_response(scale, identity, value)}
      end
    end)
    |> case do
      {:ok, {scale, response}} ->
        broadcast({:ok, scale, event_uuid}, :scale_response_added)
        {:ok, response}

      error ->
        error
    end
  end

  # A shared lock lets attendees answer side by side while an edit of the range
  # waits for them, and them for it.
  defp lock_open_scale(event_uuid, id) do
    event_files =
      from(pf in Claper.Presentations.PresentationFile,
        join: e in assoc(pf, :event),
        where: e.uuid == ^event_uuid,
        select: pf.id
      )

    from(s in Scale,
      where:
        s.id == ^id and s.enabled == true and s.presentation_file_id in subquery(event_files),
      lock: "FOR SHARE"
    )
    |> Repo.one()
  end

  defp insert_response(scale, identity, value) do
    %ScaleResponse{}
    |> ScaleResponse.changeset(Map.put(identity_attrs(identity), :value, value), scale)
    |> Repo.insert()
    |> case do
      {:ok, response} -> response
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  @doc """
  Returns the response one attendee gave to a scale, or `nil`.
  """
  def get_response_for(%Scale{id: id}, identity) do
    from(r in ScaleResponse, where: r.scale_id == ^id)
    |> where_identity(identity)
    |> Repo.one()
  end

  @doc """
  Returns every response to a scale, oldest first.
  """
  def list_responses(scale_id, preload \\ []) do
    from(r in ScaleResponse, where: r.scale_id == ^scale_id, order_by: [asc: r.id])
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @doc """
  Computes the results of a scale from its responses.

  `average` and `median` are `nil` while nobody has answered. The distribution
  lists every point of the scale, lowest first, with its count, its share of
  all responses in percent and its weight, which is its count relative to the
  most chosen point (100 for that point).

  ## Examples

      iex> results(scale)
      %{count: 3, average: 6.0, median: 7.0, distribution: [%{value: 1, count: 0, percentage: 0.0, weight: 0.0}, ...]}

  """
  def results(%Scale{id: id} = scale) do
    %{count: count, average: average, median: median} =
      from(r in ScaleResponse,
        where: r.scale_id == ^id,
        select: %{
          count: count(r.id),
          average: avg(r.value),
          median: fragment("percentile_cont(0.5) WITHIN GROUP (ORDER BY ?)", r.value)
        }
      )
      |> Repo.one()

    counts =
      from(r in ScaleResponse,
        where: r.scale_id == ^id,
        group_by: r.value,
        select: {r.value, count(r.id)}
      )
      |> Repo.all()
      |> Map.new()

    most = counts |> Map.values() |> Enum.max(fn -> 0 end)

    distribution =
      for value <- Scale.points(scale) do
        value_count = Map.get(counts, value, 0)

        %{
          value: value,
          count: value_count,
          percentage: share(value_count, count),
          weight: share(value_count, most)
        }
      end

    %{
      count: count,
      average: average && Decimal.to_float(average),
      median: median,
      distribution: distribution
    }
  end

  defp share(_part, 0), do: 0.0
  defp share(part, whole), do: part / whole * 100

  defp where_identity(query, user_id) when is_integer(user_id),
    do: where(query, [r], r.user_id == ^user_id)

  defp where_identity(query, attendee_identifier),
    do: where(query, [r], r.attendee_identifier == ^attendee_identifier)

  defp identity_attrs(user_id) when is_integer(user_id), do: %{user_id: user_id}

  defp identity_attrs(attendee_identifier),
    do: %{attendee_identifier: attendee_identifier}

  defp broadcast({:ok, scale, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, scale}
    )

    {:ok, scale}
  end
end
