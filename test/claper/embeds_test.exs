defmodule Claper.EmbedsTest do
  use Claper.DataCase

  alias Claper.Embeds

  describe "embeds" do
    alias Claper.Embeds.Embed

    import Claper.{EmbedsFixtures, PresentationsFixtures}

    @invalid_attrs %{title: nil, content: nil}

    test "list_embeds/1 returns all embeds from a presentation" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id})

      embeds = Embeds.list_embeds(presentation_file.id)
      assert [%Embed{} | _] = embeds
      assert length(embeds) == 1
      assert hd(embeds).id == embed.id
    end

    test "list_embeds_at_position/2 returns all embeds from a presentation at a given position" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id, position: 5})

      embeds = Embeds.list_embeds_at_position(presentation_file.id, 5)
      assert [%Embed{} | _] = embeds
      assert length(embeds) == 1
      assert hd(embeds).id == embed.id
      assert hd(embeds).position == 5
    end

    test "get_embed!/1 returns the embed with given id" do
      presentation_file = presentation_file_fixture()

      embed = embed_fixture(%{presentation_file_id: presentation_file.id})
      assert Embeds.get_embed!(embed.id, presentation_file: [:event]) == embed
    end

    test "create_embed/1 with valid data creates a embed" do
      presentation_file = presentation_file_fixture()

      valid_attrs = %{
        title: "some title",
        content:
          "<iframe src=\"https://www.youtube.com/embed/9bZkp7q19f0\" frameborder=\"0\" allowfullscreen></iframe>",
        provider: "custom",
        presentation_file_id: presentation_file.id,
        position: 0
      }

      assert {:ok, %Embed{} = embed} = Embeds.create_embed(valid_attrs)
      assert embed.title == "some title"

      assert embed.content ==
               "<iframe src=\"https://www.youtube.com/embed/9bZkp7q19f0\" frameborder=\"0\" allowfullscreen></iframe>"
    end

    test "create_embed/1 with valid data creates a youtube embed" do
      presentation_file = presentation_file_fixture()

      valid_attrs = %{
        title: "some title",
        content: "https://youtu.be/dQw4w9WgXcQ?si=g1A6ZegIXzcrisSw",
        provider: "youtube",
        presentation_file_id: presentation_file.id,
        position: 0
      }

      assert {:ok, %Embed{} = embed} = Embeds.create_embed(valid_attrs)
      assert embed.title == "some title"

      assert embed.content ==
               "https://youtu.be/dQw4w9WgXcQ?si=g1A6ZegIXzcrisSw"
    end

    test "create_embed/1 with invalid data creates a youtube embed" do
      presentation_file = presentation_file_fixture()

      attrs = %{
        title: "some title",
        content: "https://youtube.com/dQw4w9WgXcQ?si=g1A6ZegIXzcrisSw",
        provider: "youtube",
        presentation_file_id: presentation_file.id,
        position: 0
      }

      assert {:error, %Ecto.Changeset{}} = Embeds.create_embed(attrs)
    end

    test "create_embed/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Embeds.create_embed(@invalid_attrs)
    end

    test "update_embed/3 with valid data updates the embed" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id})

      update_attrs = %{
        title: "some updated title",
        provider: "custom",
        content:
          "<iframe src=\"https://www.youtube.com/embed/9bZkp7q19f0\" frameborder=\"0\"></iframe>"
      }

      assert {:ok, %Embed{} = embed} =
               Embeds.update_embed(presentation_file.event_id, embed, update_attrs)

      assert embed.title == "some updated title"

      assert embed.content ==
               "<iframe src=\"https://www.youtube.com/embed/9bZkp7q19f0\" frameborder=\"0\"></iframe>"
    end

    test "update_embed/3 with invalid data returns error changeset" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id})

      assert {:error, %Ecto.Changeset{}} =
               Embeds.update_embed(presentation_file.event_id, embed, @invalid_attrs)

      assert embed == Embeds.get_embed!(embed.id, presentation_file: [:event])
    end

    test "delete_embed/2 deletes the embed" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id})

      assert {:ok, %Embed{}} = Embeds.delete_embed(presentation_file.event_id, embed)
      assert_raise Ecto.NoResultsError, fn -> Embeds.get_embed!(embed.id) end
    end

    test "change_embed/1 returns a embed changeset" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id})
      assert %Ecto.Changeset{} = Embeds.change_embed(embed)
    end
  end
end
