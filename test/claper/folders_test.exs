defmodule Claper.FoldersTest do
  use Claper.DataCase

  alias Claper.Events

  import Claper.{EventsFixtures, AccountsFixtures, PresentationsFixtures}

  setup do
    %{alice: user_fixture(), bob: user_fixture()}
  end

  describe "folders" do
    test "create, rename and list ordered by name", %{alice: alice} do
      {:ok, b} = Events.create_folder(alice.id, %{"name" => "B course"})
      {:ok, _} = Events.create_folder(alice.id, %{"name" => "A course"})
      assert ["A course", "B course"] == Events.list_folders(alice.id) |> Enum.map(& &1.name)

      assert {:ok, %{name: "C course"}} = Events.update_folder(b, %{"name" => "C course"})
    end

    test "rejects blank and duplicate names per user", %{alice: alice, bob: bob} do
      assert {:error, _} = Events.create_folder(alice.id, %{"name" => "  "})
      {:ok, _} = Events.create_folder(alice.id, %{"name" => "Elixir"})
      assert {:error, cs} = Events.create_folder(alice.id, %{"name" => "Elixir"})
      assert %{name: ["has already been taken"]} = errors_on(cs)
      assert {:ok, _} = Events.create_folder(bob.id, %{"name" => "Elixir"})
    end

    test "get_user_folder! raises for a non-owner", %{alice: alice, bob: bob} do
      {:ok, folder} = Events.create_folder(alice.id, %{"name" => "Elixir"})
      assert Events.get_user_folder!(alice.id, folder.id)
      assert_raise Ecto.NoResultsError, fn -> Events.get_user_folder!(bob.id, folder.id) end
    end

    test "deleting a folder keeps its events unfiled", %{alice: alice} do
      {:ok, folder} = Events.create_folder(alice.id, %{"name" => "Elixir"})
      event = event_fixture(%{user: alice, folder_id: folder.id})
      assert event.folder_id == folder.id

      {:ok, _} = Events.delete_folder(folder)
      assert Events.get_user_event!(alice.id, event.uuid).folder_id == nil
    end

    test "an event cannot use another user's folder", %{alice: alice, bob: bob} do
      {:ok, folder} = Events.create_folder(bob.id, %{"name" => "Bob's"})

      assert {:error, cs} =
               Events.create_event(%{
                 name: "some name",
                 code: "abcde1",
                 started_at: NaiveDateTime.utc_now(),
                 user_id: alice.id,
                 folder_id: folder.id
               })

      assert %{folder_id: ["is invalid"]} = errors_on(cs)

      event = event_fixture(%{user: alice})
      assert {:error, cs} = Events.update_event(event, %{folder_id: folder.id})
      assert %{folder_id: ["is invalid"]} = errors_on(cs)
    end

    test "paginate: no key is all, nil is the top level, an id is that folder", %{alice: alice} do
      {:ok, folder} = Events.create_folder(alice.id, %{"name" => "Elixir"})
      inside = event_fixture(%{user: alice, folder_id: folder.id})
      outside = event_fixture(%{user: alice})

      ids = fn params ->
        {events, _, _} = Events.paginate_not_expired_events(alice.id, params)
        events |> Enum.map(& &1.id) |> Enum.sort()
      end

      assert ids.(%{}) == Enum.sort([inside.id, outside.id])
      assert ids.(%{"folder_id" => nil}) == [outside.id]
      assert ids.(%{"folder_id" => folder.id}) == [inside.id]
    end
  end

  describe "nested folders" do
    test "same name allowed under different parents, rejected among siblings", %{alice: alice} do
      {:ok, a} = Events.create_folder(alice.id, %{"name" => "A"})
      {:ok, b} = Events.create_folder(alice.id, %{"name" => "B"})

      assert {:ok, _} =
               Events.create_folder(alice.id, %{"name" => "Lecture", "parent_id" => a.id})

      assert {:ok, _} =
               Events.create_folder(alice.id, %{"name" => "Lecture", "parent_id" => b.id})

      assert {:error, cs} =
               Events.create_folder(alice.id, %{"name" => "Lecture", "parent_id" => a.id})

      assert %{name: ["has already been taken"]} = errors_on(cs)
    end

    test "list_child_folders and folder_path", %{alice: alice} do
      {:ok, a} = Events.create_folder(alice.id, %{"name" => "Courses"})
      {:ok, b} = Events.create_folder(alice.id, %{"name" => "Elixir", "parent_id" => a.id})
      {:ok, c} = Events.create_folder(alice.id, %{"name" => "Lecture 1", "parent_id" => b.id})

      assert [a.id] == Events.list_child_folders(alice.id, nil) |> Enum.map(& &1.id)
      assert [b.id] == Events.list_child_folders(alice.id, a.id) |> Enum.map(& &1.id)
      assert [a.id, b.id, c.id] == Events.folder_path(c) |> Enum.map(& &1.id)

      assert {"Courses / Elixir / Lecture 1", c.id} in Events.folder_options(alice.id)
    end

    test "get_user_folder_by_path! resolves names from the top level down", %{
      alice: alice,
      bob: bob
    } do
      {:ok, a} = Events.create_folder(alice.id, %{"name" => "Courses"})
      {:ok, b} = Events.create_folder(alice.id, %{"name" => "Lecture", "parent_id" => a.id})
      {:ok, c} = Events.create_folder(alice.id, %{"name" => "Other"})
      {:ok, d} = Events.create_folder(alice.id, %{"name" => "Lecture", "parent_id" => c.id})

      assert Events.get_user_folder_by_path!(alice.id, ["Courses"]).id == a.id
      assert Events.get_user_folder_by_path!(alice.id, ["Courses", "Lecture"]).id == b.id
      assert Events.get_user_folder_by_path!(alice.id, ["Other", "Lecture"]).id == d.id

      # not a top-level folder, wrong order, someone else's, or empty
      for {user, names} <- [
            {alice, ["Lecture"]},
            {alice, ["Lecture", "Courses"]},
            {bob, ["Courses"]},
            {alice, []}
          ] do
        assert_raise Ecto.NoResultsError, fn ->
          Events.get_user_folder_by_path!(user.id, names)
        end
      end
    end

    test "names cannot contain a slash or be a dot segment", %{alice: alice} do
      for name <- ["a/b", ".", ".."] do
        assert {:error, cs} = Events.create_folder(alice.id, %{"name" => name})
        assert %{name: [_]} = errors_on(cs)
      end
    end

    test "rejects a parent of another user", %{alice: alice, bob: bob} do
      {:ok, bobs} = Events.create_folder(bob.id, %{"name" => "Bob's"})

      assert {:error, cs} =
               Events.create_folder(alice.id, %{"name" => "Mine", "parent_id" => bobs.id})

      assert %{parent_id: ["is invalid"]} = errors_on(cs)
    end

    test "rejects moving a folder into itself or a descendant", %{alice: alice} do
      {:ok, a} = Events.create_folder(alice.id, %{"name" => "A"})
      {:ok, b} = Events.create_folder(alice.id, %{"name" => "B", "parent_id" => a.id})

      assert {:error, cs} = Events.update_folder(a, %{"parent_id" => a.id})
      assert %{parent_id: ["is invalid"]} = errors_on(cs)
      assert {:error, cs} = Events.update_folder(a, %{"parent_id" => b.id})
      assert %{parent_id: ["is invalid"]} = errors_on(cs)

      assert {:ok, %{parent_id: nil}} = Events.update_folder(b, %{"parent_id" => ""})
    end

    test "folder_options can leave out a folder and its descendants", %{alice: alice} do
      {:ok, a} = Events.create_folder(alice.id, %{"name" => "A"})
      {:ok, b} = Events.create_folder(alice.id, %{"name" => "B", "parent_id" => a.id})
      {:ok, c} = Events.create_folder(alice.id, %{"name" => "C"})

      ids = Events.folder_options(alice.id, exclude: a) |> Enum.map(&elem(&1, 1))
      assert ids == [c.id]
      refute b.id in ids
    end

    test "deleting a folder moves subfolders up and leaves its events unfiled", %{alice: alice} do
      {:ok, a} = Events.create_folder(alice.id, %{"name" => "A"})
      {:ok, b} = Events.create_folder(alice.id, %{"name" => "B", "parent_id" => a.id})
      {:ok, c} = Events.create_folder(alice.id, %{"name" => "C", "parent_id" => b.id})
      event = event_fixture(%{user: alice, folder_id: b.id})

      assert {:ok, %{deleted_events: []}} = Events.delete_folder(b)

      assert Events.get_user_folder!(alice.id, c.id).parent_id == a.id
      assert Events.get_user_event!(alice.id, event.uuid).folder_id == nil
    end

    test "deleting a folder can delete the events directly inside it", %{alice: alice} do
      {:ok, a} = Events.create_folder(alice.id, %{"name" => "A"})
      {:ok, b} = Events.create_folder(alice.id, %{"name" => "B", "parent_id" => a.id})
      inside = event_fixture(%{user: alice, folder_id: a.id})
      nested = event_fixture(%{user: alice, folder_id: b.id})
      outside = event_fixture(%{user: alice})

      presentation_file_fixture(%{user: alice, event: inside})

      assert {:ok, %{deleted_events: [deleted]}} = Events.delete_folder(a, delete_events: true)
      assert deleted.id == inside.id
      assert_raise Ecto.NoResultsError, fn -> Events.get_user_event!(alice.id, inside.uuid) end

      # events of subfolders and unrelated events are untouched
      assert Events.get_user_event!(alice.id, nested.uuid).folder_id == b.id
      assert Events.get_user_event!(alice.id, outside.uuid)
      assert Events.get_user_folder!(alice.id, b.id).parent_id == nil
    end

    test "deleting a folder fails if a moved subfolder would clash", %{alice: alice} do
      {:ok, a} = Events.create_folder(alice.id, %{"name" => "A"})
      {:ok, b} = Events.create_folder(alice.id, %{"name" => "B", "parent_id" => a.id})
      {:ok, _} = Events.create_folder(alice.id, %{"name" => "A2", "parent_id" => b.id})
      {:ok, _} = Events.create_folder(alice.id, %{"name" => "Same", "parent_id" => b.id})
      {:ok, _} = Events.create_folder(alice.id, %{"name" => "Same", "parent_id" => a.id})

      assert {:error, :name_conflict} = Events.delete_folder(b)
      assert Events.get_user_folder!(alice.id, b.id)
    end
  end
end
