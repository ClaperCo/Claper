defmodule Claper.PresentationsTest do
  use Claper.DataCase

  alias Claper.Presentations

  describe "presentation_files" do
    alias Claper.Presentations.PresentationFile

    import Claper.PresentationsFixtures

    test "get_presentation_file!/2 returns the presentation_file with given id" do
      presentation_file = presentation_file_fixture()
      assert Presentations.get_presentation_file!(presentation_file.id) == presentation_file
    end

    test "get_presentation_files_by_hash!/2 returns the presentation_file with given hash" do
      presentation_file = presentation_file_fixture(%{})

      assert Presentations.get_presentation_files_by_hash(presentation_file.hash) ==
               [presentation_file]
    end

    test "create_presentation_file/1 with valid data creates a presentation_file" do
      valid_attrs = %{hash: "1234", length: 42}

      assert {:ok, %PresentationFile{} = presentation_file} =
               Presentations.create_presentation_file(valid_attrs)

      assert presentation_file.hash == "1234"
      assert presentation_file.length == 42
    end

    test "update_presentation_file/2 with valid data updates the presentation_file" do
      presentation_file = presentation_file_fixture()
      update_attrs = %{hash: "4567", length: 43}

      assert {:ok, %PresentationFile{} = presentation_file} =
               Presentations.update_presentation_file(presentation_file, update_attrs)

      assert presentation_file.hash == "4567"
      assert presentation_file.length == 43
    end

    test "missing_slide_thumbnails?/1 returns true when thumbnails are missing" do
      storage_dir = unique_storage_dir()
      put_local_storage_config(storage_dir)

      presentation_file = presentation_file_fixture(%{hash: "missing-thumbs", length: 2})

      assert Presentations.missing_slide_thumbnails?(presentation_file)
    end

    test "missing_slide_thumbnails?/1 returns false when thumbnails exist" do
      storage_dir = unique_storage_dir()
      put_local_storage_config(storage_dir)

      presentation_file = presentation_file_fixture(%{hash: "existing-thumbs", length: 2})

      thumbs_dir = Path.join([storage_dir, "uploads", presentation_file.hash, "thumbs"])
      File.mkdir_p!(thumbs_dir)
      File.write!(Path.join(thumbs_dir, "1.jpg"), "thumb")

      refute Presentations.missing_slide_thumbnails?(presentation_file)
    end
  end

  describe "slide ordering" do
    import Claper.PresentationsFixtures
    import Claper.PollsFixtures

    test "get_slide_urls/1 and get_slide_thumbnail_urls/1 honor slide_order" do
      put_local_storage_config(unique_storage_dir())

      presentation_file = presentation_file_fixture(%{hash: "ordered", length: 3})

      {:ok, presentation_file} =
        Presentations.update_presentation_file(presentation_file, %{slide_order: [3, 1, 2]})

      assert Presentations.get_slide_urls(presentation_file) == [
               "/uploads/ordered/3.jpg",
               "/uploads/ordered/1.jpg",
               "/uploads/ordered/2.jpg"
             ]

      assert Presentations.get_slide_thumbnail_urls(presentation_file) == [
               "/uploads/ordered/thumbs/3.jpg",
               "/uploads/ordered/thumbs/1.jpg",
               "/uploads/ordered/thumbs/2.jpg"
             ]
    end

    test "a stale slide_order falls back to natural order" do
      put_local_storage_config(unique_storage_dir())

      presentation_file = presentation_file_fixture(%{hash: "stale", length: 3})

      {:ok, presentation_file} =
        Presentations.update_presentation_file(presentation_file, %{slide_order: [2, 1]})

      assert Presentations.get_slide_urls(presentation_file) == [
               "/uploads/stale/1.jpg",
               "/uploads/stale/2.jpg",
               "/uploads/stale/3.jpg"
             ]
    end

    test "update_presentation_file/2 clears slide_order with a nil param" do
      presentation_file = presentation_file_fixture()

      {:ok, presentation_file} =
        Presentations.update_presentation_file(presentation_file, %{slide_order: [2, 1]})

      assert presentation_file.slide_order == [2, 1]

      {:ok, presentation_file} =
        Presentations.update_presentation_file(presentation_file, %{"slide_order" => nil})

      assert is_nil(presentation_file.slide_order)
    end

    test "reorder_slides/3 remaps slide order, interactions and state position" do
      presentation_file = presentation_file_fixture(%{length: 5})
      presentation_state_fixture(%{presentation_file: presentation_file, position: 1})

      poll_at_0 = poll_fixture(%{presentation_file_id: presentation_file.id, position: 0})
      poll_at_3 = poll_fixture(%{presentation_file_id: presentation_file.id, position: 3})

      # Move the slide displayed at position 3 to position 0
      assert {:ok, presentation_file, state} =
               Presentations.reorder_slides(presentation_file, 3, 0)

      assert presentation_file.slide_order == [4, 1, 2, 3, 5]
      assert state.position == 2
      assert Claper.Polls.get_poll!(poll_at_0.id).position == 1
      assert Claper.Polls.get_poll!(poll_at_3.id).position == 0

      # Moving it back restores the natural order
      assert {:ok, presentation_file, state} =
               Presentations.reorder_slides(presentation_file, 0, 3)

      assert presentation_file.slide_order == [1, 2, 3, 4, 5]
      assert state.position == 1
      assert Claper.Polls.get_poll!(poll_at_0.id).position == 0
      assert Claper.Polls.get_poll!(poll_at_3.id).position == 3
    end

    test "reorder_slides/3 rejects invalid positions" do
      presentation_file = presentation_file_fixture(%{length: 5})

      assert {:error, :invalid_position} = Presentations.reorder_slides(presentation_file, 0, 0)
      assert {:error, :invalid_position} = Presentations.reorder_slides(presentation_file, -1, 2)
      assert {:error, :invalid_position} = Presentations.reorder_slides(presentation_file, 0, 5)
    end
  end

  describe "presentation_states" do
    alias Claper.Presentations.PresentationState

    import Claper.PresentationsFixtures

    test "create_presentation_state/1 with valid data creates a presentation_state" do
      valid_attrs = %{}

      assert {:ok, %PresentationState{}} = Presentations.create_presentation_state(valid_attrs)
    end

    test "update_presentation_state/2 with valid data updates the presentation_state" do
      presentation_state = presentation_state_fixture()
      update_attrs = %{}

      assert {:ok, %PresentationState{}} =
               Presentations.update_presentation_state(presentation_state, update_attrs)
    end

    test "authenticated_chat_only?/1 returns false by default" do
      presentation_file = presentation_file_fixture()
      presentation_state_fixture(%{presentation_file: presentation_file})

      refute Presentations.authenticated_chat_only?(presentation_file.event_id)
    end

    test "authenticated_chat_only?/1 returns true once the moderator enabled it" do
      presentation_file = presentation_file_fixture()
      presentation_state = presentation_state_fixture(%{presentation_file: presentation_file})

      {:ok, _presentation_state} =
        Presentations.update_presentation_state(presentation_state, %{
          authenticated_chat_only: true
        })

      assert Presentations.authenticated_chat_only?(presentation_file.event_id)
    end

    test "authenticated_chat_only?/1 returns false for an unknown event" do
      refute Presentations.authenticated_chat_only?(-1)
    end

    test "update_presentation_state/2 refuses to change who may post while messages are off" do
      presentation_state = presentation_state_fixture(%{chat_enabled: false})

      assert {:error, changeset} =
               Presentations.update_presentation_state(presentation_state, %{
                 authenticated_chat_only: true
               })

      assert "can only be changed while messages are enabled" in errors_on(changeset).authenticated_chat_only

      assert {:error, changeset} =
               Presentations.update_presentation_state(presentation_state, %{
                 anonymous_chat_enabled: false
               })

      assert "can only be changed while messages are enabled" in errors_on(changeset).anonymous_chat_enabled

      reloaded = Claper.Repo.reload!(presentation_state)

      refute reloaded.authenticated_chat_only
      assert reloaded.anonymous_chat_enabled
    end

    test "update_presentation_state/2 accepts the change that switches messages on with it" do
      presentation_state = presentation_state_fixture(%{chat_enabled: false})

      assert {:ok, %PresentationState{} = presentation_state} =
               Presentations.update_presentation_state(presentation_state, %{
                 chat_enabled: true,
                 authenticated_chat_only: true
               })

      assert presentation_state.authenticated_chat_only
    end

    test "update_presentation_state/2 reads whether messages are on from the database" do
      # The fixture hands back a struct whose chat_enabled is still nil while
      # the stored row carries the column default.
      presentation_state = presentation_state_fixture()

      assert {:ok, %PresentationState{authenticated_chat_only: true}} =
               Presentations.update_presentation_state(presentation_state, %{
                 authenticated_chat_only: true
               })
    end
  end

  defp put_local_storage_config(storage_dir) do
    previous_storage_dir = Application.get_env(:claper, :storage_dir)
    previous_presentations = Application.get_env(:claper, :presentations)

    Application.put_env(:claper, :storage_dir, storage_dir)

    Application.put_env(
      :claper,
      :presentations,
      Keyword.merge(previous_presentations || [], storage: "local")
    )

    on_exit(fn ->
      File.rm_rf!(storage_dir)
      Application.put_env(:claper, :storage_dir, previous_storage_dir)
      Application.put_env(:claper, :presentations, previous_presentations)
    end)
  end

  defp unique_storage_dir do
    Path.join(System.tmp_dir!(), "claper-test-#{System.unique_integer([:positive])}")
  end
end
