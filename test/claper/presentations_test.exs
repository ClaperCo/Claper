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
  end
end
