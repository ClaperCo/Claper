defmodule Claper.PostsTest do
  use Claper.DataCase

  alias Claper.Posts

  import Claper.{PostsFixtures, AccountsFixtures, EventsFixtures}

  alias Claper.Posts.Post

  describe "posts" do

    @invalid_attrs %{body: "a"}

    test "list_posts/0 returns all posts from an event" do
      post = post_fixture(%{}, [:event])
      assert Posts.list_posts(post.event.uuid, [:event]) == [post]
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture(%{}, [:event])
      assert Posts.get_post!(post.uuid, [:event]) == post
    end

    test "create_post/1 with valid data creates a post" do
      user = user_fixture()
      event = event_fixture()
      valid_attrs = %{body: "some body", user_id: user.id, event_id: event.id}

      assert {:ok, %Post{} = post} = Posts.create_post(event, valid_attrs)
      assert post.body == "some body"
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Posts.create_post(%{}, @invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()
      update_attrs = %{body: "some updated body"}

      assert {:ok, %Post{} = post} = Posts.update_post(post, update_attrs)
      assert post.body == "some updated body"
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture(%{}, [:event])
      assert {:error, %Ecto.Changeset{}} = Posts.update_post(post, @invalid_attrs)
      assert post == Posts.get_post!(post.uuid, [:event])
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Posts.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Posts.get_post!(post.uuid) end
    end
  end


  describe "reactions" do
    alias Claper.Posts.Reaction

    import Claper.PostsFixtures

    @invalid_attrs %{icon: nil, post: nil}

    test "reacted_posts/3 from a post for a given user" do
      post = post_fixture()
      reaction = reaction_fixture(%{post: post, user_id: post.user_id})

      assert Posts.reacted_posts(post.event_id, post.user_id, reaction.icon) == [post.id]
    end

    test "create_reaction/1 with valid data creates a reaction" do
      post = post_fixture()
      valid_attrs = %{icon: "some icon", post: post, user_id: post.user_id}

      assert {:ok, %Reaction{} = reaction} = Posts.create_reaction(valid_attrs)
      assert reaction.icon == "some icon"
    end

    test "create_reaction/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Posts.create_reaction(@invalid_attrs)
    end

    test "delete_reaction/1 deletes the reaction" do
      post = post_fixture()
      reaction = reaction_fixture(%{post: post, user_id: post.user_id})

      assert {:ok, %Post{}} = Posts.delete_reaction(%{user_id: post.user_id, post: post, icon: "some icon"})
      assert_raise Ecto.NoResultsError, fn -> Posts.get_reaction!(reaction.id) end
    end
  end
end
