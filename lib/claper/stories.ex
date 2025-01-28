defmodule Claper.Stories do
  @moduledoc """
  The Stories context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Stories.Story
  alias Claper.Stories.StoryOpt
  alias Claper.Stories.StoryVote

  @doc """
  Returns the list of stories for a given presentation file.

  ## Examples

      iex> list_stories(123)
      [%Story{}, ...]

  """
  def list_stories(presentation_file_id) do
    from(p in Story,
      where: p.presentation_file_id == ^presentation_file_id,
      order_by: [asc: p.id, asc: p.position]
    )
    |> Repo.all()
    |> Repo.preload([:story_opts])
  end

  @doc """
  Returns the list of stories for a given presentation file and a given position.

  ## Examples

      iex> list_stories_at_position(123, 0)
      [%Story{}, ...]

  """
  def list_stories_at_position(presentation_file_id, position) do
    from(p in Story,
      where: p.presentation_file_id == ^presentation_file_id and p.position == ^position,
      order_by: [asc: p.id]
    )
    |> Repo.all()
    |> Repo.preload([:story_opts])
  end

  @doc """
  Gets a single story and set percentages for each story options.

  Raises `Ecto.NoResultsError` if the Story does not exist.

  ## Examples

      iex> get_story!(123)
      %Story{}

      iex> get_story!(456)
      ** (Ecto.NoResultsError)

  """
  def get_story!(id),
    do:
      Repo.get!(Story, id)
      |> Repo.preload(
        story_opts:
          from(
            o in StoryOpt,
            order_by: [asc: o.id]
          )
      )
      |> set_percentages()

  @doc """
  Gets a single story for a given position.

  ## Examples

      iex> get_story!(123, 0)
      %Story{}

  """
  def get_story_current_position(presentation_file_id, position) do
    from(p in Story,
      where:
        p.position == ^position and p.presentation_file_id == ^presentation_file_id and
          p.enabled == true
    )
    |> Repo.one()
    |> Repo.preload(
      story_opts:
        from(
          o in StoryOpt,
          order_by: [asc: o.id]
        )
    )
    |> set_percentages()
  end

  @doc """
  Determines the next-slide based on the submitted votes for a story.

  ## Examples

      iex> set_next_slide(story)
      %Story{}

  """
  def set_next_slide(%Story{story_opts: story_opts} = story) when is_list(story_opts) do
    nxt_sld = Enum.max_by(story.story_opts, & &1.vote_count).next_slide

    story
    |> Story.changeset(%{story_result: nxt_sld})
    |> Repo.update()
  end

  @doc """
  Calculate percentage of all story options for a given story.

  ## Examples

      iex> set_percentages(story)
      %Story{}

  """
  def set_percentages(%Story{story_opts: story_opts} = story) when is_list(story_opts) do
    total = Enum.map(story.story_opts, fn e -> e.vote_count end) |> Enum.sum()

    %{
      story
      | story_opts:
          story.story_opts
          |> Enum.map(fn o -> %{o | percentage: calculate_percentage(o, total)} end)
    }
  end

  def set_percentages(story), do: story

  defp calculate_percentage(opt, total) do
    if total > 0,
      do: Float.round(opt.vote_count / total * 100) |> :erlang.float_to_binary(decimals: 0),
      else: 0
  end

  @doc """
  Creates a story.

  ## Examples

      iex> create_story(%{field: value})
      {:ok, %Story{}}

      iex> create_story(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_story(attrs \\ %{}) do
    %Story{}
    |> Story.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, story} ->
        story = Repo.preload(story, presentation_file: :event)
        broadcast({:ok, story, story.presentation_file.event.uuid}, :story_created)

      {:error, changeset} ->
        {:error, %{changeset | action: :insert}}
    end
  end

  @doc """
  Updates a story.

  ## Examples

      iex> update_story("123e4567-e89b-12d3-a456-426614174000", story, %{field: new_value})
      {:ok, %Story{}}

      iex> update_story("123e4567-e89b-12d3-a456-426614174000", story, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_story(event_uuid, %Story{} = story, attrs) do
    story
    |> Story.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, story} ->
        set_next_slide(story)
        broadcast({:ok, story, event_uuid}, :story_updated)

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Deletes a story.

  ## Examples

      iex> delete_story("123e4567-e89b-12d3-a456-426614174000", story)
      {:ok, %Story{}}

      iex> delete_story("123e4567-e89b-12d3-a456-426614174000", story)
      {:error, %Ecto.Changeset{}}

  """
  def delete_story(event_uuid, %Story{} = story) do
    {:ok, story} = Repo.delete(story)
    broadcast({:ok, story, event_uuid}, :story_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking story changes.

  ## Examples

      iex> change_story(story)
      %Ecto.Changeset{data: %Story{}}

  """
  def change_story(%Story{} = story, attrs \\ %{}) do
    Story.changeset(story, attrs)
  end

  @doc """
  Add an empty story opt to a story changeset.
  """
  def add_story_opt(changeset) do
    changeset
    |> Ecto.Changeset.put_assoc(
      :story_opts,
      Ecto.Changeset.get_field(changeset, :story_opts) ++ [%StoryOpt{}]
    )
  end

  @doc """
  Remove a story opt from a story changeset.
  """
  def remove_story_opt(changeset, story_opt) do
    changeset
    |> Ecto.Changeset.put_assoc(
      :story_opts,
      Ecto.Changeset.get_field(changeset, :story_opts) -- [story_opt]
    )
  end

  def vote(user_id, event_uuid, story_opts, story_id)
      when is_number(user_id) and is_list(story_opts) do
    case Enum.reduce(story_opts, Ecto.Multi.new(), fn opt, multi ->
           Ecto.Multi.update(
             multi,
             {:update_story_opt, opt.id},
             StoryOpt.changeset(opt, %{"vote_count" => opt.vote_count + 1})
           )
           |> Ecto.Multi.insert(
             {:insert_story_vote, opt.id},
             StoryVote.changeset(%StoryVote{}, %{
               user_id: user_id,
               story_opt_id: opt.id,
               story_id: story_id
             })
           )
         end)
         |> Repo.transaction() do
      {:ok, _} ->
        story = get_story!(story_id)
        set_next_slide(story)
        broadcast({:ok, story, event_uuid}, :story_updated)
    end
  end

  def vote(attendee_identifier, event_uuid, story_opts, story_id) when is_list(story_opts) do
    case Enum.reduce(story_opts, Ecto.Multi.new(), fn opt, multi ->
           Ecto.Multi.update(
             multi,
             {:update_story_opt, opt.id},
             StoryOpt.changeset(opt, %{"vote_count" => opt.vote_count + 1})
           )
           |> Ecto.Multi.insert(
             {:insert_story_vote, opt.id},
             StoryVote.changeset(%StoryVote{}, %{
               attendee_identifier: attendee_identifier,
               story_opt_id: opt.id,
               story_id: story_id
             })
           )
         end)
         |> Repo.transaction() do
      {:ok, _} ->
        story = get_story!(story_id)
        set_next_slide(story)
        broadcast({:ok, story, event_uuid}, :story_updated)
    end
  end

  def disable_all(presentation_file_id, position) do
    from(p in Story,
      where: p.presentation_file_id == ^presentation_file_id and p.position == ^position
    )
    |> Repo.update_all(set: [enabled: false])
  end

  def set_enabled(id) do
    get_story!(id)
    |> Ecto.Changeset.change(enabled: true)
    |> Repo.update()
  end

  def set_disabled(id) do
    get_story!(id)
    |> Ecto.Changeset.change(enabled: false)
    |> Repo.update()
  end

  defp broadcast({:ok, story, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, story}
    )

    {:ok, story}
  end

  @doc """
  Gets a all story_vote.


  ## Examples

      iex> get_story_vote!(321, 123)
      [%StoryVote{}]

  """
  def get_story_vote(user_id, story_id) when is_number(user_id) do
    from(p in StoryVote,
      where: p.story_id == ^story_id and p.user_id == ^user_id,
      order_by: [asc: p.id]
    )
    |> Repo.all()
  end

  def get_story_vote(attendee_identifier, story_id) do
    from(p in StoryVote,
      where: p.story_id == ^story_id and p.attendee_identifier == ^attendee_identifier,
      order_by: [asc: p.id]
    )
    |> Repo.all()
  end

  @doc """
  Creates a story_vote.

  ## Examples

      iex> create_story_vote(%{field: value})
      {:ok, %StoryVote{}}

      iex> create_story_vote(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_story_vote(attrs \\ %{}) do
    %StoryVote{}
    |> StoryVote.changeset(attrs)
    |> Repo.insert()
  end
end
