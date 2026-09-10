defmodule Claper.Polls do
  @moduledoc """
  The Polls context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Polls.Poll
  alias Claper.Polls.PollOpt
  alias Claper.Polls.PollVote

  @orphaned_ratings_message "cannot leave out ratings that have already been submitted"

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
    Ecto.Multi.new()
    |> Ecto.Multi.run(:for_new_type, fn repo, _changes -> for_new_type(repo, poll, attrs) end)
    |> Ecto.Multi.run(:poll, fn repo, %{for_new_type: {poll, attrs}} ->
      poll
      |> Poll.changeset(attrs)
      |> reject_orphaned_ratings(repo, poll)
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{poll: poll}} ->
        broadcast({:ok, poll, event_uuid}, :poll_updated)

      {:error, :poll, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, %{changeset | action: :update}}

      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  # A poll's options belong to its type: the author's answers on a :choice poll,
  # the attendees' rating buckets on a :slider one. Switching the type therefore
  # drops the rows of the previous type -- and, through the foreign key, the
  # votes cast on them -- instead of carrying them over into a poll where they
  # mean something else. It runs inside the update transaction, so a rejected
  # change leaves the options alone.
  defp for_new_type(repo, %Poll{} = poll, attrs) do
    case selected_type(attrs) do
      type when type in [:choice, :slider] and type != poll.type ->
        repo.delete_all(from(o in PollOpt, where: o.poll_id == ^poll.id))
        {:ok, {%{poll | poll_opts: []}, drop_poll_opts_attr(type, attrs)}}

      _unchanged ->
        {:ok, {poll, attrs}}
    end
  end

  # A slider poll's options are the ratings its audience has already submitted.
  # Narrowing the range would leave the ones outside it counting into
  # `average_rating/1` while `rating_distribution/1`, which walks the range,
  # stops showing them -- an average that matches no bar of its own graph. So
  # the change is refused on the field that would cut those ratings off, with a
  # message the edit form renders next to it, and both the range and the ratings
  # stay as they were. Dropping the slider type altogether is a different story:
  # `for_new_type/3` has deleted those rows before this runs.
  defp reject_orphaned_ratings(%Ecto.Changeset{valid?: true} = changeset, repo, %Poll{} = poll) do
    if Ecto.Changeset.get_field(changeset, :type) == :slider do
      ratings = submitted_ratings(repo, poll)

      changeset
      |> reject_ratings_below(Ecto.Changeset.get_field(changeset, :min_value), ratings)
      |> reject_ratings_above(Ecto.Changeset.get_field(changeset, :max_value), ratings)
    else
      changeset
    end
  end

  defp reject_orphaned_ratings(changeset, _repo, _poll), do: changeset

  defp submitted_ratings(repo, %Poll{id: poll_id}) do
    from(o in PollOpt, where: o.poll_id == ^poll_id and o.vote_count > 0)
    |> repo.all()
    |> Enum.flat_map(fn opt ->
      case rating_of(opt) do
        {:ok, value} -> [value]
        :error -> []
      end
    end)
  end

  defp reject_ratings_below(changeset, min, ratings) when is_integer(min) do
    if Enum.any?(ratings, &(&1 < min)),
      do: Ecto.Changeset.add_error(changeset, :min_value, @orphaned_ratings_message),
      else: changeset
  end

  defp reject_ratings_below(changeset, _min, _ratings), do: changeset

  defp reject_ratings_above(changeset, max, ratings) when is_integer(max) do
    if Enum.any?(ratings, &(&1 > max)),
      do: Ecto.Changeset.add_error(changeset, :max_value, @orphaned_ratings_message),
      else: changeset
  end

  defp reject_ratings_above(changeset, _max, _ratings), do: changeset

  defp selected_type(attrs) do
    case Map.get(attrs, "type") || Map.get(attrs, :type) do
      nil -> nil
      type when is_atom(type) -> type
      type when is_binary(type) -> Enum.find([:choice, :slider], &(to_string(&1) == type))
    end
  end

  defp drop_poll_opts_attr(:slider, attrs),
    do: attrs |> Map.delete("poll_opts") |> Map.delete(:poll_opts)

  defp drop_poll_opts_attr(_type, attrs), do: attrs

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
    Poll.changeset(poll, attrs)
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

  @doc """
  Records a vote on the options an attendee picked in a choice poll.

  Returns `{:error, :not_a_choice}` when the poll takes ratings instead of
  pre-defined choices -- `submit_rating/4` is the way into those -- and
  `{:error, :unknown_poll_opt}` when one of the given options is not one of
  this poll's own.

  ## Examples

      iex> vote(attendee_identifier, event_uuid, [%PollOpt{}], poll_id)
      {:ok, %Poll{}}

  """
  def vote(user_id, event_uuid, poll_opts, poll_id)
      when is_number(user_id) and is_list(poll_opts) do
    cast_votes(%{user_id: user_id}, event_uuid, poll_opts, poll_id)
  end

  def vote(attendee_identifier, event_uuid, poll_opts, poll_id) when is_list(poll_opts) do
    cast_votes(%{attendee_identifier: attendee_identifier}, event_uuid, poll_opts, poll_id)
  end

  defp cast_votes(voter, event_uuid, poll_opts, poll_id) do
    poll = get_poll!(poll_id)

    with :ok <- ensure_choice(poll),
         :ok <- ensure_own_opts(poll, poll_opts) do
      poll_opts
      |> Enum.reduce(Ecto.Multi.new(), fn opt, multi ->
        multi
        |> Ecto.Multi.update(
          {:update_poll_opt, opt.id},
          PollOpt.changeset(opt, %{"vote_count" => opt.vote_count + 1})
        )
        |> Ecto.Multi.insert(
          {:insert_poll_vote, opt.id},
          PollVote.changeset(
            %PollVote{},
            Map.merge(voter, %{poll_opt_id: opt.id, poll_id: poll_id})
          )
        )
      end)
      |> Repo.transaction()
      |> case do
        {:ok, _} -> broadcast({:ok, get_poll!(poll_id), event_uuid}, :poll_updated)
        {:error, _operation, reason, _changes} -> {:error, reason}
      end
    end
  end

  # The counterpart of ensure_slider/1: a slider poll's options are the buckets
  # of the ratings its audience submitted, not answers anybody may pick. Without
  # this an attendee could push "select-poll-opt" and "vote" at a running slider
  # poll and have a rating counted for a value they never named -- or crash the
  # view while no bucket exists at all.
  defp ensure_choice(%Poll{type: :slider}), do: {:error, :not_a_choice}
  defp ensure_choice(%Poll{}), do: :ok

  # The options come from the client's index into the poll on screen, so they
  # are only trustworthy once they have been found in this poll again.
  defp ensure_own_opts(%Poll{poll_opts: poll_opts}, voted_opts) when is_list(poll_opts) do
    own_ids = MapSet.new(poll_opts, & &1.id)

    if Enum.all?(voted_opts, fn opt ->
         match?(%PollOpt{}, opt) and MapSet.member?(own_ids, opt.id)
       end),
       do: :ok,
       else: {:error, :unknown_poll_opt}
  end

  defp ensure_own_opts(_poll, _voted_opts), do: {:error, :unknown_poll_opt}

  @doc """
  Submits a rating for a slider poll. A slider poll keeps one poll_opt per value
  of its range -- the bucket the value's votes are counted in, keyed by its
  `rating_value` -- so the rating is written as a single upsert: it creates that
  bucket the first time somebody picks the value, and increments the one that is
  already there afterwards. Also records a PollVote the same way a regular
  choice vote does, so "have I already voted" (`get_poll_vote/2`) works
  identically for both poll types.

  Returns `{:error, :not_a_slider}` when the poll takes pre-defined choices
  rather than ratings, `{:error, :out_of_range}` when the value is not a whole
  number inside the poll's own `min_value`..`max_value` range, and
  `{:error, :already_voted}` when this attendee has rated this poll before.

  ## Examples

      iex> submit_rating(attendee_identifier, event_uuid, poll_id, "7")
      {:ok, %Poll{}}

      iex> submit_rating(attendee_identifier, event_uuid, poll_id, "42")
      {:error, :out_of_range}

  """
  def submit_rating(identifier, event_uuid, poll_id, value) do
    poll = get_poll!(poll_id)

    with :ok <- ensure_slider(poll),
         {:ok, rating} <- cast_rating(poll, value),
         {:ok, _poll_opt} <- record_rating(identifier, poll_id, rating) do
      broadcast({:ok, get_poll!(poll_id), event_uuid}, :poll_updated)
    end
  end

  # Only a slider poll gets its options from its audience. Without this the
  # "submit-rating" event would let any attendee add an option to a choice poll,
  # where the moderator alone decides what can be picked.
  defp ensure_slider(%Poll{type: :slider}), do: :ok
  defp ensure_slider(%Poll{}), do: {:error, :not_a_slider}

  # One rating per attendee. The form takes itself off screen once you have
  # rated, but a second tab, a stale view or a reconnect can push
  # "submit-rating" again, and the average must not count that voice twice.
  # The check sits inside the transaction that writes the rating, so a second
  # push cannot slip between the question and the answer.
  defp ensure_first_rating(identifier, poll_id) do
    case get_poll_vote(identifier, poll_id) do
      [] -> :ok
      [_already | _] -> {:error, :already_voted}
    end
  end

  defp record_rating(identifier, poll_id, rating) do
    Repo.transaction(fn ->
      with :ok <- ensure_first_rating(identifier, poll_id),
           {:ok, poll_opt} <- rated_poll_opt(poll_id, rating),
           {:ok, _vote} <- insert_rating_vote(identifier, poll_id, poll_opt) do
        poll_opt
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # One statement, so two attendees rating the same value at the same moment
  # cannot end up with two buckets for it, nor lose one of the two counts:
  # (poll_id, rating_value) is unique, and a conflict increments the row that
  # is already there.
  defp rated_poll_opt(poll_id, rating) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %PollOpt{}
    |> PollOpt.rating_changeset(%{
      content: Integer.to_string(rating),
      rating_value: rating,
      vote_count: 1,
      poll_id: poll_id
    })
    |> Repo.insert(
      on_conflict: [inc: [vote_count: 1], set: [updated_at: now]],
      conflict_target: [:poll_id, :rating_value],
      returning: true
    )
  end

  defp insert_rating_vote(identifier, poll_id, poll_opt) do
    vote_attrs = %{poll_opt_id: poll_opt.id, poll_id: poll_id}

    vote_attrs =
      if is_number(identifier),
        do: Map.put(vote_attrs, :user_id, identifier),
        else: Map.put(vote_attrs, :attendee_identifier, identifier)

    %PollVote{} |> PollVote.changeset(vote_attrs) |> Repo.insert()
  end

  defp cast_rating(%Poll{} = poll, value) when is_binary(value) do
    case Integer.parse(value) do
      {rating, ""} -> cast_rating(poll, rating)
      _ -> {:error, :out_of_range}
    end
  end

  defp cast_rating(%Poll{min_value: min, max_value: max}, value)
       when is_integer(value) and value >= min and value <= max,
       do: {:ok, value}

  defp cast_rating(_poll, _value), do: {:error, :out_of_range}

  # The value a bucket stands for. `rating_value` is the column the database
  # keys the buckets by; the content is the fallback for rows written before
  # that column existed.
  defp rating_of(%PollOpt{rating_value: rating}) when is_integer(rating), do: {:ok, rating}

  defp rating_of(%PollOpt{content: content}) when is_binary(content) do
    case Integer.parse(content) do
      {rating, _rest} -> {:ok, rating}
      :error -> :error
    end
  end

  defp rating_of(_opt), do: :error

  @doc """
  Average of every rating submitted to a slider poll, rounded to one decimal.
  Returns `nil` while nobody has rated yet, so callers can tell "no votes"
  apart from a genuine average of 0.

  ## Examples

      iex> average_rating(poll)
      7.4

  """
  def average_rating(%Poll{poll_opts: poll_opts}) when is_list(poll_opts) do
    {sum, count} =
      Enum.reduce(poll_opts, {0, 0}, fn opt, {sum, count} ->
        case rating_of(opt) do
          {:ok, value} -> {sum + value * opt.vote_count, count + opt.vote_count}
          :error -> {sum, count}
        end
      end)

    if count > 0, do: Float.round(sum / count, 1), else: nil
  end

  def average_rating(_poll), do: nil

  @doc """
  Vote spread of a slider poll, one entry per value of its range -- values
  nobody picked included, so the graph keeps the shape of the scale. The
  `percentage` is relative to the most picked value, not to the total, so the
  tallest bar always fills its container.

  ## Examples

      iex> rating_distribution(poll)
      [%{value: 1, vote_count: 0, percentage: 0}, %{value: 2, vote_count: 4, percentage: 100}]

  """
  def rating_distribution(%Poll{poll_opts: poll_opts} = poll) when is_list(poll_opts) do
    counts =
      Enum.reduce(poll_opts, %{}, fn opt, acc ->
        case rating_of(opt) do
          {:ok, value} -> Map.update(acc, value, opt.vote_count, &(&1 + opt.vote_count))
          :error -> acc
        end
      end)

    highest = counts |> Map.values() |> Enum.max(fn -> 0 end)

    Enum.map(poll.min_value..poll.max_value, fn value ->
      vote_count = Map.get(counts, value, 0)

      %{
        value: value,
        vote_count: vote_count,
        percentage: if(highest > 0, do: round(vote_count / highest * 100), else: 0)
      }
    end)
  end

  def rating_distribution(_poll), do: []

  @doc """
  Middle of a slider poll's range, where the slider starts before the attendee
  moves it.

  ## Examples

      iex> default_rating(poll)
      5

  """
  def default_rating(%Poll{min_value: min, max_value: max})
      when is_integer(min) and is_integer(max),
      do: div(min + max, 2)

  def default_rating(_poll), do: 0

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
