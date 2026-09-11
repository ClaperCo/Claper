defmodule Claper.PostsTest do
  use Claper.DataCase

  alias Claper.Posts

  import Claper.{PostsFixtures, AccountsFixtures, EventsFixtures, PresentationsFixtures}

  alias Claper.Posts.{Post, PostReply}

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
      valid_attrs = %{body: "some body", user_id: user.id, event_id: event.id, name: "some name"}

      assert {:ok, %Post{} = post} = Posts.create_post(event, valid_attrs)
      assert post.body == "some body"
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Posts.create_post(%{}, @invalid_attrs)
    end

    test "create_post/2 refuses a post without an author when the event requires a login" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        anonymous_chat_enabled: true,
        authenticated_chat_only: true
      })

      assert {:error, changeset} =
               Posts.create_post(presentation_file.event, %{
                 "body" => "posted straight through the context",
                 "attendee_identifier" => "anon-1",
                 "position" => 0,
                 "name" => "Troll"
               })

      assert "must be logged in to post a message" in errors_on(changeset).user_id
      assert Posts.list_posts(presentation_file.event.uuid) == []
    end

    test "create_post/3 accepts a post from a logged in author when the event requires a login" do
      user = user_fixture()
      presentation_file = presentation_file_fixture(%{}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        authenticated_chat_only: true
      })

      assert {:ok, %Post{}} =
               Posts.create_post(
                 presentation_file.event,
                 %{
                   "body" => "a legitimate question",
                   "position" => 0
                 },
                 user
               )

      assert [%Post{body: "a legitimate question"}] =
               Posts.list_posts(presentation_file.event.uuid)
    end

    test "create_post/3 takes the author from the caller, not from the params" do
      author = user_fixture()
      impostor = user_fixture()
      event = event_fixture()

      assert {:ok, %Post{} = post} =
               Posts.create_post(
                 event,
                 %{"body" => "some body", "position" => 0, "user_id" => impostor.id},
                 author
               )

      assert post.user_id == author.id
    end

    test "create_post/2 refuses a params supplied author when the event requires a login" do
      user = user_fixture()
      presentation_file = presentation_file_fixture(%{}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        anonymous_chat_enabled: true,
        authenticated_chat_only: true
      })

      assert {:error, changeset} =
               Posts.create_post(presentation_file.event, %{
                 "body" => "posted under a stolen name",
                 "attendee_identifier" => "anon-1",
                 "position" => 0,
                 "user_id" => user.id
               })

      assert "must be logged in to post a message" in errors_on(changeset).user_id
      assert Posts.list_posts(presentation_file.event.uuid) == []
    end

    test "create_post/2 accepts a post without an author while the event does not require a login" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        anonymous_chat_enabled: true
      })

      assert {:ok, %Post{}} =
               Posts.create_post(presentation_file.event, %{
                 "body" => "an anonymous question",
                 "attendee_identifier" => "anon-1",
                 "position" => 0
               })
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

    test "create_post_reply/4 appends multiple host replies in order" do
      host = user_fixture()
      event = event_fixture(%{user: host})
      post = post_fixture(%{event: event})
      actor = {:user, host, nil}

      assert {:ok, %PostReply{body: "First answer", author_role: :host}} =
               Posts.create_post_reply(event, post.uuid, actor, "First answer")

      assert {:ok, %PostReply{body: "Second answer", author_role: :host}} =
               Posts.create_post_reply(event, post.uuid, actor, "Second answer")

      replied_post = Posts.get_post!(post.uuid, [:replies])
      assert Enum.map(replied_post.replies, & &1.body) == ["First answer", "Second answer"]
    end

    test "create_post_reply/4 lets the anonymous root author reply" do
      event = event_fixture()

      post =
        post_fixture(%{
          event: event,
          user_id: nil,
          attendee_identifier: "attendee-1",
          name: "Ada"
        })

      assert {:ok, %PostReply{} = reply} =
               Posts.create_post_reply(
                 event,
                 post.uuid,
                 {:attendee, "attendee-1", "Ada"},
                 "Follow-up"
               )

      assert reply.author_role == :attendee
      assert reply.author_name == "Ada"
      assert reply.attendee_identifier == "attendee-1"
    end

    test "create_post_reply/4 rejects other attendees" do
      event = event_fixture()
      post = post_fixture(%{event: event, user_id: nil, attendee_identifier: "attendee-1"})

      assert {:error, :forbidden} =
               Posts.create_post_reply(
                 event,
                 post.uuid,
                 {:attendee, "attendee-2", "Grace"},
                 "Not my thread"
               )
    end

    test "create_post_reply/4 returns an error changeset for a blank reply" do
      host = user_fixture()
      event = event_fixture(%{user: host})
      post = post_fixture(%{event: event})

      assert {:error, %Ecto.Changeset{}} =
               Posts.create_post_reply(event, post.uuid, {:user, host, nil}, "   ")
    end

    test "delete_post_reply/3 permits the reply author" do
      event = event_fixture()

      post =
        post_fixture(%{
          event: event,
          user_id: nil,
          attendee_identifier: "attendee-1",
          name: "Ada"
        })

      actor = {:attendee, "attendee-1", "Ada"}
      {:ok, reply} = Posts.create_post_reply(event, post.uuid, actor, "Remove me")

      assert {:ok, %PostReply{}} = Posts.delete_post_reply(event, reply.uuid, actor)
      assert Posts.get_post!(post.uuid, [:replies]).replies == []
    end

    test "facilitators can create and delete replies" do
      owner = user_fixture()
      facilitator = user_fixture()
      event = event_fixture(%{user: owner})
      activity_leader_fixture(%{event: event, user: facilitator})
      post = post_fixture(%{event: event})
      actor = {:user, facilitator, nil}

      assert {:ok, %PostReply{author_role: :host} = reply} =
               Posts.create_post_reply(event, post.uuid, actor, "Facilitator answer")

      assert {:ok, %PostReply{}} = Posts.delete_post_reply(event, reply.uuid, actor)
      assert Posts.get_post!(post.uuid, [:replies]).replies == []
    end

    test "delete_post_reply/3 rejects other attendees and scopes replies to the event" do
      event = event_fixture()
      other_event = event_fixture()

      post =
        post_fixture(%{
          event: event,
          user_id: nil,
          attendee_identifier: "attendee-1"
        })

      {:ok, reply} =
        Posts.create_post_reply(
          event,
          post.uuid,
          {:attendee, "attendee-1", "Ada"},
          "Keep me"
        )

      assert {:error, :forbidden} =
               Posts.delete_post_reply(event, reply.uuid, {:attendee, "attendee-2", "Grace"})

      assert {:error, :not_found} =
               Posts.delete_post_reply(
                 other_event,
                 reply.uuid,
                 {:attendee, "attendee-1", "Ada"}
               )

      assert [%PostReply{uuid: reply_uuid}] = Posts.get_post!(post.uuid, [:replies]).replies
      assert reply_uuid == reply.uuid
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Posts.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Posts.get_post!(post.uuid) end
    end

    test "get_post_for_event/3 returns post when it belongs to the event" do
      event = event_fixture()
      post = post_fixture(%{event: event}, [:event])

      fetched_post = Posts.get_post_for_event(post.uuid, event.id, [:event])
      assert fetched_post.id == post.id
    end

    test "get_post_for_event/3 returns nil when post belongs to a different event" do
      event_a = event_fixture()
      event_b = event_fixture()
      post = post_fixture(%{event: event_a})

      assert is_nil(Posts.get_post_for_event(post.uuid, event_b.id))
    end

    test "get_post_for_event/3 returns nil for nonexistent post uuid" do
      event = event_fixture()
      assert is_nil(Posts.get_post_for_event(Ecto.UUID.generate(), event.id))
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

      assert {:ok, %Post{}} =
               Posts.delete_reaction(%{user_id: post.user_id, post: post, icon: "some icon"})

      assert_raise Ecto.NoResultsError, fn -> Posts.get_reaction!(reaction.id) end
    end
  end
end
