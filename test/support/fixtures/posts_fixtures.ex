defmodule Claper.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Posts` context.
  """

  import Claper.{AccountsFixtures, EventsFixtures}

  require Claper.UtilFixture

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}, preload \\ []) do
    user = attrs[:user] || user_fixture()
    event = attrs[:event] || event_fixture()
    assoc = %{user: user, event: event}
    {:ok, post} =
      Claper.Posts.create_post(assoc.event, attrs
      |> Enum.into(%{
        body: "some body",
        like_count: 42,
        position: 0,
        uuid: Ecto.UUID.generate(),
        user_id: assoc.user.id
      }))

      Claper.UtilFixture.merge_preload(post, preload, assoc)
  end


  @doc """
  Generate a reaction.
  """
  def reaction_fixture(attrs \\ %{}) do
    {:ok, reaction} =
      attrs
      |> Enum.into(%{
        icon: "some icon"
      })
      |> Claper.Posts.create_reaction()

    reaction
  end
end
