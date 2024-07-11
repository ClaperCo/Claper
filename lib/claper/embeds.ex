defmodule Claper.Embeds do
  @moduledoc """
  The Embeds context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Embeds.Embed

  @doc """
  Returns the list of embeds for a given presentation file.

  ## Examples

      iex> list_embeds(123)
      [%Embed{}, ...]

  """
  def list_embeds(presentation_file_id) do
    from(e in Embed,
      where: e.presentation_file_id == ^presentation_file_id,
      order_by: [asc: e.id, asc: e.position]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of embeds for a given presentation file and a given position.

  ## Examples

      iex> list_embeds_at_position(123, 0)
      [%Embed{}, ...]

  """
  def list_embeds_at_position(presentation_file_id, position) do
    from(e in Embed,
      where: e.presentation_file_id == ^presentation_file_id and e.position == ^position,
      order_by: [asc: e.id]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single embed.

  Raises `Ecto.NoResultsError` if the Embed does not exist.

  ## Examples

      iex> get_embed!(123)
      %Embed{}

      iex> get_embed!(456)
      ** (Ecto.NoResultsError)

  """
  def get_embed!(id, preload \\ []),
    do: Repo.get!(Embed, id) |> Repo.preload(preload)

  @doc """
  Gets a single embed for a given position.

  ## Examples

      iex> get_embed_current_position(123, 0)
      %Embed{}

  """
  def get_embed_current_position(presentation_file_id, position) do
    from(e in Embed,
      where:
        e.position == ^position and e.presentation_file_id == ^presentation_file_id and
          e.enabled == true
    )
    |> Repo.one()
  end

  @doc """
  Creates a embed.

  ## Examples

      iex> create_embed(%{field: value})
      {:ok, %Embed{}}

      iex> create_embed(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_embed(attrs \\ %{}) do
    %Embed{}
    |> Embed.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, embed} ->
        embed = Repo.preload(embed, presentation_file: :event)
        broadcast({:ok, embed, embed.presentation_file.event.uuid}, :embed_created)

      {:error, changeset} ->
        {:error, %{changeset | action: :insert}}
    end
  end

  @doc """
  Updates a embed.

  ## Examples

      iex> update_embed("123e4567-e89b-12d3-a456-426614174000", embed, %{field: new_value})
      {:ok, %Embed{}}

      iex> update_embed("123e4567-e89b-12d3-a456-426614174000", embed, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_embed(event_uuid, %Embed{} = embed, attrs) do
    embed
    |> Embed.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, embed} ->
        broadcast({:ok, embed, event_uuid}, :embed_updated)

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Deletes a embed.

  ## Examples

      iex> delete_embed("123e4567-e89b-12d3-a456-426614174000", embed)
      {:ok, %Embed{}}

      iex> delete_embed("123e4567-e89b-12d3-a456-426614174000", embed)
      {:error, %Ecto.Changeset{}}

  """
  def delete_embed(event_uuid, %Embed{} = embed) do
    {:ok, embed} = Repo.delete(embed)
    broadcast({:ok, embed, event_uuid}, :embed_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking embed changes.

  ## Examples

      iex> change_embed(embed)
      %Ecto.Changeset{data: %Embed{}}

  """
  def change_embed(%Embed{} = embed, attrs \\ %{}) do
    Embed.changeset(embed, attrs)
  end

  def disable_all(presentation_file_id, position) do
    from(e in Embed,
      where: e.presentation_file_id == ^presentation_file_id and e.position == ^position
    )
    |> Repo.update_all(set: [enabled: false])
  end

  def set_enabled(id) do
    get_embed!(id)
    |> Ecto.Changeset.change(enabled: true)
    |> Repo.update()
  end

  def set_disabled(id) do
    get_embed!(id)
    |> Ecto.Changeset.change(enabled: false)
    |> Repo.update()
  end

  defp broadcast({:error, _reason} = error, _embed), do: error

  defp broadcast({:ok, embed, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, embed}
    )

    {:ok, embed}
  end
end
