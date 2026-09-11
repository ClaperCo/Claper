defmodule Claper.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Posts.{Post, PostReply}

  @doc """
  Get event posts

  """
  def list_posts(event_id, preload \\ []) do
    from(p in Post,
      join: e in Claper.Events.Event,
      on: p.event_id == e.id,
      select: p,
      where: e.uuid == ^event_id,
      order_by: [asc: p.id]
    )
    |> Repo.all()
    |> Repo.preload(preload)
    |> Repo.preload(replies: :user)
  end

  @doc """
  Get event posts which are questions

  """
  def list_questions(event_id, preload \\ [], sort \\ :date) do
    query =
      from(p in Post,
        join: e in assoc(p, :event),
        where: e.uuid == ^event_id and like(p.body, "%?%")
      )

    query =
      case sort do
        :likes -> from(p in query, order_by: [desc: p.like_count])
        _ -> from(p in query, order_by: [asc: p.id])
      end

    query
    |> Repo.all()
    |> Repo.preload(preload)
    |> Repo.preload(replies: :user)
  end

  @doc """
  Get only the pinned event posts.
  """
  def list_pinned_posts(event_id, preload \\ []) do
    from(p in Post,
      join: e in Claper.Events.Event,
      on: p.event_id == e.id,
      select: p,
      # Only pinned posts
      where: e.uuid == ^event_id and p.pinned == true,
      order_by: [asc: p.id]
    )
    |> Repo.all()
    |> Repo.preload(preload)
    |> Repo.preload(replies: :user)
  end

  @doc """
  Get only the unpinned event posts.
  """
  def list_unpinned_posts(event_id, preload \\ []) do
    from(p in Post,
      join: e in Claper.Events.Event,
      on: p.event_id == e.id,
      select: p,
      # Only unpinned posts
      where: e.uuid == ^event_id and p.pinned == false,
      order_by: [asc: p.id]
    )
    |> Repo.all()
    |> Repo.preload(preload)
    |> Repo.preload(replies: :user)
  end

  def reacted_posts(event_id, user_id, icon) when is_number(user_id) do
    from(reaction in Claper.Posts.Reaction,
      join: post in Claper.Posts.Post,
      on: reaction.post_id == post.id,
      where:
        reaction.icon == ^icon and reaction.user_id == ^user_id and
          post.event_id == ^event_id,
      distinct: true,
      select: reaction.post_id
    )
    |> Repo.all()
  end

  def reacted_posts(event_id, attendee_identifier, icon) do
    from(reaction in Claper.Posts.Reaction,
      join: post in Claper.Posts.Post,
      on: reaction.post_id == post.id,
      where:
        reaction.icon == ^icon and
          reaction.attendee_identifier == ^attendee_identifier and post.event_id == ^event_id,
      distinct: true,
      select: reaction.post_id
    )
    |> Repo.all()
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!("123e4567-e89b-12d3-a456-426614174000")
      %Post{}

      iex> get_post!("123e4567-e89b-12d3-a456-426614174123")
      ** (Ecto.NoResultsError)

  """
  def get_post!(id, preload \\ []) do
    Post
    |> Repo.get_by!(uuid: id)
    |> Repo.preload(preload)
    |> Repo.preload(replies: :user)
  end

  @doc """
  Gets a single post scoped to the given event.

  Returns `nil` if the post does not exist or does not belong to the event.
  """
  def get_post_for_event(uuid, event_id, preload \\ []) do
    from(p in Post,
      where: p.uuid == ^uuid and p.event_id == ^event_id
    )
    |> Repo.one()
    |> case do
      nil -> nil
      post -> post |> Repo.preload(preload) |> Repo.preload(replies: :user)
    end
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(event, %{field: value})
      {:ok, %Post{}}

      iex> create_post(event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(event, attrs) do
    %Post{}
    |> Map.put(:event, event)
    |> Post.changeset(attrs)
    |> Repo.insert(returning: [:uuid])
    |> broadcast(:post_created)
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    changeset = Post.changeset(post, attrs)

    result = changeset |> Repo.update()

    result |> broadcast(:post_updated)
  end

  @doc """
  Adds a reply when the actor is an event host or the original post author.
  """
  def create_post_reply(event, post_uuid, actor, body) do
    with %Post{} = post <- get_post_for_event(post_uuid, event.id, [:event]),
         {:ok, author_attrs} <- reply_author_attrs(event, post, actor),
         attrs <-
           Map.merge(author_attrs, %{
             body: normalize_reply_body(body),
             post_id: post.id
           }),
         {:ok, reply} <-
           %PostReply{}
           |> PostReply.changeset(attrs)
           |> Repo.insert(returning: [:uuid]) do
      broadcast_post(post, :post_updated)
      {:ok, reply}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Deletes a reply when the actor authored it or is an event host.
  """
  def delete_post_reply(event, reply_uuid, actor) do
    with %PostReply{} = reply <- get_post_reply_for_event(reply_uuid, event.id),
         true <- can_delete_reply?(event, reply, actor),
         {:ok, deleted_reply} <- Repo.delete(reply) do
      broadcast_post(reply.post, :post_updated)
      {:ok, deleted_reply}
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
      error -> error
    end
  end

  @doc """
  Pins or unpins a post based on its current state.

  ## Examples

      iex> toggle_pin_post(post)
      {:ok, %Post{}}

      iex> toggle_pin_post(invalid_post)
      {:error, %Ecto.Changeset{}}

  """
  def toggle_pin_post(%Post{} = post) do
    # Toggling the pinned state
    new_pinned_state = not post.pinned
    changeset = Post.changeset(post, %{pinned: new_pinned_state})

    result = changeset |> Repo.update()

    # Broadcast the appropriate message based on the new state
    broadcast_message =
      if new_pinned_state do
        :post_pinned
      else
        :post_unpinned
      end

    result |> broadcast(broadcast_message)
  end

  @doc """
  Deletes a post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    post
    |> Repo.delete()
    |> broadcast(:post_deleted)
  end

  def delete_all_posts(:attendee_identifier, attendee_identifier, event) do
    posts =
      from(post in Claper.Posts.Post,
        where: post.attendee_identifier == ^attendee_identifier and post.event_id == ^event.id
      )
      |> Repo.all()

    for post <- posts do
      delete_post(%{post | event: event})
    end
  end

  def delete_all_posts(:user_id, user_id, event) do
    posts =
      from(post in Claper.Posts.Post,
        where: post.user_id == ^user_id and post.event_id == ^event.id
      )
      |> Repo.all()

    for post <- posts do
      delete_post(%{post | event: event})
    end
  end

  alias Claper.Posts.Reaction

  @doc """
  Gets a single reaction.

  Raises `Ecto.NoResultsError` if the Reaction does not exist.

  ## Examples

      iex> get_reaction!(123)
      %Reaction{}

      iex> get_reaction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_reaction!(id), do: Repo.get!(Reaction, id)

  @doc """
  Creates a reaction.

  ## Examples

      iex> create_reaction(%{field: value})
      {:ok, %Reaction{}}

      iex> create_reaction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_reaction(%{post: nil} = attrs), do: create_reaction(%{attrs | post: %Post{}})

  def create_reaction(%{post: post} = attrs) do
    case %Reaction{}
         |> Map.put(:post_id, post.id)
         |> Reaction.changeset(attrs)
         |> Repo.insert() do
      {:ok, reaction} ->
        broadcast({:ok, post}, :reaction_added)
        {:ok, reaction}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a reaction.

  ## Examples

      iex> delete_reaction(reaction)
      {:ok, %Reaction{}}

      iex> delete_reaction(reaction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_reaction(%{user_id: user_id, post: post, icon: icon} = _params)
      when is_integer(user_id) do
    with reaction <- Repo.get_by!(Reaction, post_id: post.id, user_id: user_id, icon: icon) do
      Repo.delete(reaction)
      broadcast({:ok, post}, :reaction_removed)
    end
  end

  def delete_reaction(
        %{attendee_identifier: attendee_identifier, post: post, icon: icon} = _params
      ) do
    with reaction <-
           Repo.get_by!(Reaction,
             post_id: post.id,
             attendee_identifier: attendee_identifier,
             icon: icon
           ) do
      Repo.delete(reaction)
      broadcast({:ok, post}, :reaction_removed)
    end
  end

  defp get_post_reply_for_event(uuid, event_id) do
    from(reply in PostReply,
      join: post in assoc(reply, :post),
      where: reply.uuid == ^uuid and post.event_id == ^event_id
    )
    |> Repo.one()
    |> case do
      nil -> nil
      reply -> Repo.preload(reply, post: :event)
    end
  end

  defp reply_author_attrs(event, _post, {:user, user, _name})
       when event.user_id == user.id do
    {:ok, %{author_role: :host, user_id: user.id}}
  end

  defp reply_author_attrs(event, post, {:user, user, name}) do
    cond do
      Claper.Events.led_by?(user.email, event) ->
        {:ok, %{author_role: :host, user_id: user.id}}

      post.user_id == user.id ->
        {:ok,
         %{author_role: :attendee, user_id: user.id, author_name: normalize_author_name(name)}}

      true ->
        {:error, :forbidden}
    end
  end

  defp reply_author_attrs(_event, post, {:attendee, attendee_identifier, name}) do
    if post.attendee_identifier == attendee_identifier and not is_nil(attendee_identifier) do
      {:ok,
       %{
         author_role: :attendee,
         attendee_identifier: attendee_identifier,
         author_name: normalize_author_name(name)
       }}
    else
      {:error, :forbidden}
    end
  end

  defp can_delete_reply?(event, reply, {:user, user, _name}) do
    event.user_id == user.id || Claper.Events.led_by?(user.email, event) ||
      reply.user_id == user.id
  end

  defp can_delete_reply?(_event, reply, {:attendee, attendee_identifier, _name}) do
    not is_nil(attendee_identifier) && reply.attendee_identifier == attendee_identifier
  end

  defp normalize_reply_body(body) when is_binary(body), do: String.trim(body)
  defp normalize_reply_body(body), do: body

  defp normalize_author_name(name) when name in [nil, ""], do: nil
  defp normalize_author_name(name), do: name

  defp broadcast_post(post, event) do
    post
    |> Repo.preload([:event, replies: :user], force: true)
    |> then(&Phoenix.PubSub.broadcast(Claper.PubSub, "event:#{&1.event.uuid}", {event, &1}))
  end

  defp broadcast({:error, _reason} = error, _event), do: error

  defp broadcast({:ok, post}, event) do
    post = Repo.preload(post, [:event, replies: :user], force: true)
    Phoenix.PubSub.broadcast(Claper.PubSub, "event:#{post.event.uuid}", {event, post})
    {:ok, post}
  end
end
