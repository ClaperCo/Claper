defmodule Claper.Polls do
  @moduledoc """
  The Polls context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Polls.Poll
  alias Claper.Polls.PollOpt
  alias Claper.Polls.PollVote

  @doc """
  Returns the list of polls for a given presentation file.

  ## Examples

      iex> list_polls(123)
      [%Poll{}, ...]

  """
  def list_polls(presentation_file_id) do
    from(p in Poll,
      where: p.presentation_file_id == ^presentation_file_id,
      order_by: [asc: p.id, asc: p.position]
    )
    |> Repo.all()
    |> Repo.preload([:poll_opts])
  end

  @doc """
  Returns the list of polls for a given presentation file and a given position.

  ## Examples

      iex> list_polls_at_position(123, 0)
      [%Poll{}, ...]

  """
  def list_polls_at_position(presentation_file_id, position) do
    from(p in Poll,
      where: p.presentation_file_id == ^presentation_file_id and p.position == ^position,
      order_by: [asc: p.id]
    )
    |> Repo.all()
    |> Repo.preload([:poll_opts])
  end

  @doc """
  Gets a single poll and set percentages for each poll options.

  Raises `Ecto.NoResultsError` if the Poll does not exist.

  ## Examples

      iex> get_poll!(123)
      %Poll{}

      iex> get_poll!(456)
      ** (Ecto.NoResultsError)

  """
  def get_poll!(id),
    do:
      Repo.get!(Poll, id)
      |> Repo.preload(
        poll_opts:
          from(
            o in PollOpt,
            order_by: [asc: o.id]
          )
      )
      |> set_percentages()

  @doc """
  Gets a single poll scoped to the given event.

  Returns `nil` if the poll does not exist or does not belong to the event.
  """
  def get_poll_for_event(id, event_id) do
    from(p in Poll,
      join: pf in assoc(p, :presentation_file),
      where: p.id == ^id and pf.event_id == ^event_id
    )
    |> Repo.one()
    |> case do
      nil ->
        nil

      poll ->
        poll
        |> Repo.preload(
          poll_opts:
            from(
              o in PollOpt,
              order_by: [asc: o.id]
            )
        )
        |> set_percentages()
    end
  end

  @doc """
  Gets a single poll for a given position.

  ## Examples

      iex> get_poll!(123, 0)
      %Poll{}

  """
  def get_poll_current_position(presentation_file_id, position) do
    from(p in Poll,
      where:
        p.position == ^position and p.presentation_file_id == ^presentation_file_id and
          p.enabled == true
    )
    |> Repo.one()
    |> Repo.preload(
      poll_opts:
        from(
          o in PollOpt,
          order_by: [asc: o.id]
        )
    )
    |> set_percentages()
  end

  @doc """
  Calculate percentage of all poll options for a given poll.

  ## Examples

      iex> set_percentages(poll)
      %Poll{}

  """
  def set_percentages(%Poll{poll_opts: poll_opts} = poll) when is_list(poll_opts) do
    total = Enum.map(poll.poll_opts, fn e -> e.vote_count end) |> Enum.sum()

    %{
      poll
      | poll_opts:
          poll.poll_opts
          |> Enum.map(fn o -> %{o | percentage: calculate_percentage(o, total)} end)
    }
  end

  def set_percentages(poll), do: poll

  defp calculate_percentage(opt, total) do
    if total > 0,
      do: Float.round(opt.vote_count / total * 100) |> :erlang.float_to_binary(decimals: 0),
      else: 0
  end

  @doc """
  Creates a poll.

  ## Examples

      iex> create_poll(%{field: value})
      {:ok, %Poll{}}

      iex> create_poll(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_poll(attrs \\ %{}) do
    %Poll{}
    |> Poll.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, poll} ->
        poll = Repo.preload(poll, presentation_file: :event)
        broadcast({:ok, poll, poll.presentation_file.event.uuid}, :poll_created)

      {:error, changeset} ->
        {:error, %{changeset | action: :insert}}
    end
  end

  @doc """
  Updates a poll.

  ## Examples

      iex> update_poll("123e4567-e89b-12d3-a456-426614174000", poll, %{field: new_value})
      {:ok, %Poll{}}

      iex> update_poll("123e4567-e89b-12d3-a456-426614174000", poll, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_poll(event_uuid, %Poll{} = poll, attrs) do
    poll
    |> Poll.changeset(attrs)
    |> refuse_type_change_that_discards_answers(poll)
    |> Repo.update()
    |> case do
      {:ok, poll} ->
        broadcast({:ok, poll, event_uuid}, :poll_updated)

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  # Switching the type throws away what has already been collected. On the way to
  # a word cloud that is the list of choices -- and, because poll_votes reference
  # poll_opts with `on_delete: :delete_all`, every vote cast on them. On the way
  # back it is the words the audience typed, which would otherwise survive as the
  # choices of a poll nobody wrote, vote counts and all. Deleting a poll asks
  # first; this did the same damage silently and in both directions, so refuse it
  # here, where the change is made, rather than in the form that happens to offer
  # the select. A presenter who really means it deletes the poll.
  defp refuse_type_change_that_discards_answers(changeset, %Poll{id: nil}), do: changeset

  defp refuse_type_change_that_discards_answers(changeset, poll) do
    if Ecto.Changeset.get_change(changeset, :type) && answers_collected?(poll) do
      Ecto.Changeset.add_error(
        changeset,
        :type,
        "cannot be changed once this poll has been answered, delete the poll to start over"
      )
    else
      changeset
    end
  end

  # A word cloud only ever has the options its audience typed, so one option is
  # one answer. A choice poll's options are the presenter's own, so its answers
  # are the votes cast on them.
  defp answers_collected?(%Poll{type: :word_cloud, id: id}),
    do: Repo.exists?(from(o in PollOpt, where: o.poll_id == ^id))

  defp answers_collected?(%Poll{id: id}) do
    Repo.exists?(from(v in PollVote, where: v.poll_id == ^id)) ||
      Repo.exists?(from(o in PollOpt, where: o.poll_id == ^id and o.vote_count > 0))
  end

  @doc """
  Deletes a poll.

  ## Examples

      iex> delete_poll("123e4567-e89b-12d3-a456-426614174000", poll)
      {:ok, %Poll{}}

      iex> delete_poll("123e4567-e89b-12d3-a456-426614174000", poll)
      {:error, %Ecto.Changeset{}}

  """
  def delete_poll(event_uuid, %Poll{} = poll) do
    {:ok, poll} = Repo.delete(poll)
    broadcast({:ok, poll, event_uuid}, :poll_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking poll changes.

  ## Examples

      iex> change_poll(poll)
      %Ecto.Changeset{data: %Poll{}}

  """
  def change_poll(%Poll{} = poll, attrs \\ %{}) do
    poll
    |> Poll.changeset(attrs)
    |> refuse_type_change_that_discards_answers(poll)
  end

  @doc """
  Add an empty poll opt to a poll changeset.
  """
  def add_poll_opt(changeset) do
    changeset
    |> Ecto.Changeset.put_assoc(
      :poll_opts,
      Ecto.Changeset.get_field(changeset, :poll_opts) ++ [%PollOpt{}]
    )
  end

  @doc """
  Remove a poll opt from a poll changeset.
  """
  def remove_poll_opt(changeset, poll_opt) do
    changeset
    |> Ecto.Changeset.put_assoc(
      :poll_opts,
      Ecto.Changeset.get_field(changeset, :poll_opts) -- [poll_opt]
    )
  end

  def vote(user_id, event_uuid, poll_opts, poll_id)
      when is_number(user_id) and is_list(poll_opts) do
    case Enum.reduce(poll_opts, Ecto.Multi.new(), fn opt, multi ->
           Ecto.Multi.update(
             multi,
             {:update_poll_opt, opt.id},
             PollOpt.changeset(opt, %{"vote_count" => opt.vote_count + 1})
           )
           |> Ecto.Multi.insert(
             {:insert_poll_vote, opt.id},
             PollVote.changeset(%PollVote{}, %{
               user_id: user_id,
               poll_opt_id: opt.id,
               poll_id: poll_id
             })
           )
         end)
         |> Repo.transaction() do
      {:ok, _} ->
        poll = get_poll!(poll_id)
        broadcast({:ok, poll, event_uuid}, :poll_updated)
    end
  end

  def vote(attendee_identifier, event_uuid, poll_opts, poll_id) when is_list(poll_opts) do
    case Enum.reduce(poll_opts, Ecto.Multi.new(), fn opt, multi ->
           Ecto.Multi.update(
             multi,
             {:update_poll_opt, opt.id},
             PollOpt.changeset(opt, %{"vote_count" => opt.vote_count + 1})
           )
           |> Ecto.Multi.insert(
             {:insert_poll_vote, opt.id},
             PollVote.changeset(%PollVote{}, %{
               attendee_identifier: attendee_identifier,
               poll_opt_id: opt.id,
               poll_id: poll_id
             })
           )
         end)
         |> Repo.transaction() do
      {:ok, _} ->
        poll = get_poll!(poll_id)
        broadcast({:ok, poll, event_uuid}, :poll_updated)
    end
  end

  @doc """
  Submits a word for a word-cloud poll: matches it (case-insensitively,
  trimmed) against an existing poll_opt on this poll and increments its
  vote_count, or creates a new poll_opt if no match exists. Also records a
  PollVote the same way a regular choice vote does, so "have I already
  voted" (Polls.get_poll_vote/2) works identically for both poll types.

  Only an enabled word cloud takes words. The poll id arrives from a
  client-triggered event, so the type and the state are checked here rather
  than only in the LiveView that happens to send it: writing a word onto a
  choice poll would add an option nobody offered, enrol that choice poll in the
  partial unique index behind a word cloud's one-row-per-word rule, and record
  a vote for it.

  ## Examples

      iex> submit_word(attendee_identifier, event_uuid, poll_id, "great")
      {:ok, %Poll{}}

      iex> submit_word(attendee_identifier, event_uuid, poll_id, "")
      {:error, %Ecto.Changeset{}}

      iex> submit_word(attendee_identifier, event_uuid, choice_poll_id, "great")
      {:error, :not_an_open_word_cloud}

  """
  def submit_word(identifier, event_uuid, poll_id, word) do
    case Repo.get(Poll, poll_id) do
      %Poll{type: :word_cloud, enabled: true} ->
        add_word_to_cloud(identifier, event_uuid, poll_id, word)

      _other ->
        {:error, :not_an_open_word_cloud}
    end
  end

  defp add_word_to_cloud(identifier, event_uuid, poll_id, word) do
    Repo.transaction(fn ->
      with {:ok, poll_opt} <- upsert_word_poll_opt(poll_id, word),
           {:ok, _vote} <- create_word_poll_vote(identifier, poll_id, poll_opt) do
        poll_opt
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, _poll_opt} ->
        poll = get_poll!(poll_id)
        broadcast({:ok, poll, event_uuid}, :poll_updated)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # One row per word per poll, decided by the database instead of by a lookup
  # followed by an insert: two attendees submitting the same word at the same
  # moment both hit the unique index on (poll_id, normalized_content), and the
  # one that arrives second increments the row the first one wrote rather than
  # adding a second row for the same word.
  defp upsert_word_poll_opt(poll_id, word) do
    %PollOpt{}
    |> PollOpt.word_changeset(%{content: word, vote_count: 1, poll_id: poll_id})
    |> Repo.insert(
      on_conflict: [inc: [vote_count: 1]],
      conflict_target:
        {:unsafe_fragment, "(poll_id, normalized_content) WHERE normalized_content IS NOT NULL"},
      returning: true
    )
  end

  defp create_word_poll_vote(identifier, poll_id, poll_opt) do
    %PollVote{}
    |> PollVote.changeset(word_poll_vote_attrs(identifier, poll_id, poll_opt))
    |> Repo.insert()
  end

  defp word_poll_vote_attrs(user_id, poll_id, poll_opt) when is_number(user_id),
    do: %{poll_opt_id: poll_opt.id, poll_id: poll_id, user_id: user_id}

  defp word_poll_vote_attrs(attendee_identifier, poll_id, poll_opt),
    do: %{
      poll_opt_id: poll_opt.id,
      poll_id: poll_id,
      attendee_identifier: attendee_identifier
    }

  def disable_all(presentation_file_id, position) do
    from(p in Poll,
      where: p.presentation_file_id == ^presentation_file_id and p.position == ^position
    )
    |> Repo.update_all(set: [enabled: false])
  end

  def set_enabled(id) do
    get_poll!(id)
    |> Ecto.Changeset.change(enabled: true)
    |> Repo.update()
  end

  def set_disabled(id) do
    get_poll!(id)
    |> Ecto.Changeset.change(enabled: false)
    |> Repo.update()
  end

  defp broadcast({:ok, poll, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, poll}
    )

    {:ok, poll}
  end

  @doc """
  Gets a all poll_vote.


  ## Examples

      iex> get_poll_vote!(321, 123)
      [%PollVote{}]

  """
  def get_poll_vote(user_id, poll_id) when is_number(user_id) do
    from(p in PollVote,
      where: p.poll_id == ^poll_id and p.user_id == ^user_id,
      order_by: [asc: p.id]
    )
    |> Repo.all()
  end

  def get_poll_vote(attendee_identifier, poll_id) do
    from(p in PollVote,
      where: p.poll_id == ^poll_id and p.attendee_identifier == ^attendee_identifier,
      order_by: [asc: p.id]
    )
    |> Repo.all()
  end

  @doc """
  Creates a poll_vote.

  ## Examples

      iex> create_poll_vote(%{field: value})
      {:ok, %PollVote{}}

      iex> create_poll_vote(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_poll_vote(attrs \\ %{}) do
    %PollVote{}
    |> PollVote.changeset(attrs)
    |> Repo.insert()
  end
end
