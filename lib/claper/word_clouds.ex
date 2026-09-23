defmodule Claper.WordClouds do
  @moduledoc """
  The WordClouds context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.WordClouds.Entry
  alias Claper.WordClouds.WordCloud

  @doc """
  Returns the list of word clouds for a given presentation file.

  ## Examples

      iex> list_word_clouds(123)
      [%WordCloud{}, ...]

  """
  def list_word_clouds(presentation_file_id) do
    from(w in WordCloud,
      where: w.presentation_file_id == ^presentation_file_id,
      order_by: [asc: w.id, asc: w.position]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of word clouds for a given presentation file and a given position.

  ## Examples

      iex> list_word_clouds_at_position(123, 0)
      [%WordCloud{}, ...]

  """
  def list_word_clouds_at_position(presentation_file_id, position) do
    from(w in WordCloud,
      where: w.presentation_file_id == ^presentation_file_id and w.position == ^position,
      order_by: [asc: w.id]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single word cloud.

  Raises `Ecto.NoResultsError` if the WordCloud does not exist.

  ## Examples

      iex> get_word_cloud!(123)
      %WordCloud{}

      iex> get_word_cloud!(456)
      ** (Ecto.NoResultsError)

  """
  def get_word_cloud!(id, preload \\ []),
    do: Repo.get!(WordCloud, id) |> Repo.preload(preload)

  @doc """
  Gets a single word cloud scoped to the given event.

  Returns `nil` if the word cloud does not exist or does not belong to the event.
  """
  def get_word_cloud_for_event(id, event_id, preload \\ []) do
    from(w in WordCloud,
      join: pf in assoc(w, :presentation_file),
      where: w.id == ^id and pf.event_id == ^event_id
    )
    |> Repo.one()
    |> case do
      nil -> nil
      word_cloud -> Repo.preload(word_cloud, preload)
    end
  end

  @doc """
  Gets the enabled word cloud for a given position.

  ## Examples

      iex> get_word_cloud_current_position(123, 0)
      %WordCloud{}

  """
  def get_word_cloud_current_position(presentation_file_id, position) do
    from(w in WordCloud,
      where:
        w.position == ^position and w.presentation_file_id == ^presentation_file_id and
          w.enabled == true
    )
    |> Repo.one()
  end

  @doc """
  Creates a word cloud.

  ## Examples

      iex> create_word_cloud(%{field: value})
      {:ok, %WordCloud{}}

      iex> create_word_cloud(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_word_cloud(attrs \\ %{}) do
    %WordCloud{}
    |> WordCloud.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, word_cloud} ->
        word_cloud = Repo.preload(word_cloud, presentation_file: :event)

        broadcast(
          {:ok, word_cloud, word_cloud.presentation_file.event.uuid},
          :word_cloud_created
        )

      {:error, changeset} ->
        {:error, %{changeset | action: :insert}}
    end
  end

  @doc """
  Updates a word cloud.

  ## Examples

      iex> update_word_cloud("123e4567-e89b-12d3-a456-426614174000", word_cloud, %{field: new_value})
      {:ok, %WordCloud{}}

      iex> update_word_cloud("123e4567-e89b-12d3-a456-426614174000", word_cloud, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_word_cloud(event_uuid, %WordCloud{} = word_cloud, attrs) do
    word_cloud
    |> WordCloud.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, word_cloud} ->
        broadcast({:ok, word_cloud, event_uuid}, :word_cloud_updated)

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Deletes a word cloud together with its entries.

  ## Examples

      iex> delete_word_cloud("123e4567-e89b-12d3-a456-426614174000", word_cloud)
      {:ok, %WordCloud{}}

  """
  def delete_word_cloud(event_uuid, %WordCloud{} = word_cloud) do
    {:ok, word_cloud} = Repo.delete(word_cloud)
    broadcast({:ok, word_cloud, event_uuid}, :word_cloud_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking word cloud changes.

  ## Examples

      iex> change_word_cloud(word_cloud)
      %Ecto.Changeset{data: %WordCloud{}}

  """
  def change_word_cloud(%WordCloud{} = word_cloud, attrs \\ %{}) do
    WordCloud.changeset(word_cloud, attrs)
  end

  def disable_all(presentation_file_id, position) do
    from(w in WordCloud,
      where: w.presentation_file_id == ^presentation_file_id and w.position == ^position
    )
    |> Repo.update_all(set: [enabled: false])
  end

  def set_enabled(id) do
    get_word_cloud!(id)
    |> Ecto.Changeset.change(enabled: true)
    |> Repo.update()
  end

  def set_disabled(id) do
    get_word_cloud!(id)
    |> Ecto.Changeset.change(enabled: false)
    |> Repo.update()
  end

  @doc """
  Returns the words of a word cloud, one per match key, leaving out the hidden
  ones.

  Each word carries the text of its earliest submission, how often it was sent
  and its share of all visible submissions in percent. The most frequent word
  comes first.

  ## Examples

      iex> list_words(word_cloud)
      [%{key: "elixir", text: "Elixir", count: 3, percentage: 75.0}, ...]

  """
  def list_words(%WordCloud{id: id, hidden_words: hidden_words}) do
    words =
      from(e in Entry,
        where: e.word_cloud_id == ^id and e.normalized_content not in ^hidden_words,
        group_by: e.normalized_content,
        select: %{
          key: e.normalized_content,
          text: fragment("(array_agg(? ORDER BY ?))[1]", e.content, e.id),
          count: count(e.id)
        }
      )
      |> Repo.all()

    total = words |> Enum.map(& &1.count) |> Enum.sum()

    words
    |> Enum.map(&Map.put(&1, :percentage, &1.count / total * 100))
    |> Enum.sort_by(&{-&1.count, &1.key})
  end

  @doc """
  Returns every entry of a word cloud, hidden words included, oldest first.
  """
  def list_entries(word_cloud_id, preload \\ []) do
    from(e in Entry, where: e.word_cloud_id == ^word_cloud_id, order_by: [asc: e.id])
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @doc """
  Returns the entries one attendee submitted to a word cloud, oldest first.

  The identity is a user id for a signed-in attendee and the attendee
  identifier otherwise.
  """
  def list_entries_for(%WordCloud{id: id}, identity) do
    from(e in Entry, where: e.word_cloud_id == ^id, order_by: [asc: e.id])
    |> where_identity(identity)
    |> Repo.all()
  end

  @doc """
  Adds a word to a word cloud on behalf of an attendee.

  The word cloud is loaded again and has to be enabled and to belong to the
  event, because the id comes from a client-triggered event: an attendee must
  not be able to write into a cloud that is closed or that belongs to another
  event.

  ## Examples

      iex> submit_entry(event_uuid, word_cloud, attendee_identifier, "Elixir")
      {:ok, %Entry{}}

      iex> submit_entry(event_uuid, word_cloud, attendee_identifier, "  ")
      {:error, %Ecto.Changeset{}}

      iex> submit_entry(event_uuid, closed_word_cloud, attendee_identifier, "Elixir")
      {:error, :not_an_open_word_cloud}

      iex> submit_entry(event_uuid, word_cloud, attendee_with_all_words_sent, "Elixir")
      {:error, :limit_reached}

  """
  def submit_entry(event_uuid, %WordCloud{id: id}, identity, content) do
    Repo.transaction(fn ->
      case lock_open_word_cloud(event_uuid, id) do
        nil -> Repo.rollback(:not_an_open_word_cloud)
        word_cloud -> {word_cloud, add_entry(word_cloud, identity, content)}
      end
    end)
    |> case do
      {:ok, {word_cloud, entry}} ->
        broadcast({:ok, word_cloud, event_uuid}, :word_cloud_entry_added)
        {:ok, entry}

      error ->
        error
    end
  end

  # The row lock serialises the submissions to one cloud, so two words sent at
  # the same moment by one attendee cannot both pass the max_entries count.
  defp lock_open_word_cloud(event_uuid, id) do
    event_files =
      from(pf in Claper.Presentations.PresentationFile,
        join: e in assoc(pf, :event),
        where: e.uuid == ^event_uuid,
        select: pf.id
      )

    from(w in WordCloud,
      where:
        w.id == ^id and w.enabled == true and w.presentation_file_id in subquery(event_files),
      lock: "FOR UPDATE"
    )
    |> Repo.one()
  end

  defp add_entry(word_cloud, identity, content) do
    if count_entries_for(word_cloud, identity) >= word_cloud.max_entries do
      Repo.rollback(:limit_reached)
    else
      %Entry{}
      |> Entry.changeset(
        identity
        |> identity_attrs()
        |> Map.merge(%{content: content, word_cloud_id: word_cloud.id})
      )
      |> Repo.insert()
      |> case do
        {:ok, entry} -> entry
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end
  end

  defp count_entries_for(word_cloud, identity) do
    from(e in Entry, where: e.word_cloud_id == ^word_cloud.id, select: count(e.id))
    |> where_identity(identity)
    |> Repo.one()
  end

  defp where_identity(query, user_id) when is_integer(user_id),
    do: where(query, [e], e.user_id == ^user_id)

  defp where_identity(query, attendee_identifier),
    do: where(query, [e], e.attendee_identifier == ^attendee_identifier)

  defp identity_attrs(user_id) when is_integer(user_id), do: %{user_id: user_id}

  defp identity_attrs(attendee_identifier),
    do: %{attendee_identifier: attendee_identifier}

  @doc """
  Takes a word out of the cloud. Its entries stay stored and it can be brought
  back with `unhide_word/3`.
  """
  def hide_word(event_uuid, %WordCloud{id: id}, key) when is_binary(key) do
    # The key comes from the client, so only one the cloud actually holds is kept.
    entries = from(e in Entry, where: e.word_cloud_id == ^id and e.normalized_content == ^key)

    if Repo.exists?(entries) do
      from(w in WordCloud, where: w.id == ^id and ^key not in w.hidden_words)
      |> Repo.update_all(push: [hidden_words: key])
    end

    broadcast({:ok, get_word_cloud!(id), event_uuid}, :word_cloud_updated)
  end

  @doc """
  Puts a hidden word back into the cloud.
  """
  def unhide_word(event_uuid, %WordCloud{id: id}, key) do
    from(w in WordCloud, where: w.id == ^id)
    |> Repo.update_all(pull: [hidden_words: key])

    broadcast({:ok, get_word_cloud!(id), event_uuid}, :word_cloud_updated)
  end

  defp broadcast({:ok, word_cloud, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, word_cloud}
    )

    {:ok, word_cloud}
  end
end
