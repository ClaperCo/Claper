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

    test "create_embed/1 with invalid youtube URL returns error" do
      presentation_file = presentation_file_fixture()

      attrs = %{
        title: "some title",
        # Wrong provider URL for youtube
        content: "https://vimeo.com/123456",
        provider: "youtube",
        presentation_file_id: presentation_file.id,
        position: 0,
        attendee_visibility: false
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
    end

    test "update_embed/3 with invalid data returns error changeset" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id})

      assert {:error, %Ecto.Changeset{}} =
               Embeds.update_embed(presentation_file.event_id, embed, @invalid_attrs)

      assert embed == Embeds.get_embed!(embed.id, presentation_file: [:event])
    end

    test "custom embeds reject unsafe and ambiguous sources on create and update" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id})

      for content <- [
            ~s|<iframe src="java&#x09;script:parent.document.body.dataset.securityProbe=1"></iframe>|,
            "<iframe src=\"java\tscript:alert(1)\"></iframe>",
            ~s|<iframe src='javascript:alert(1)'></iframe>|,
            ~s|<iframe src="data:text/html,<script>alert(1)</script>"></iframe>|,
            ~s|<iframe src="https:///missing-host"></iframe>|,
            ~s|<iframe src="//example.com/embed"></iframe>|,
            ~s|<iframe srcdoc="<script>alert(1)</script>" onload="alert(1)"></iframe>|,
            ~s|<iframe src="https://example.com" s&#x72;c="javascript:alert(1)"></iframe>|,
            ~s|<iframe src="https://example.com" SRC="javascript:alert(1)"></iframe>|,
            ~s|<iframe src="javascript:alert(1)" src="https://example.com"></iframe>|,
            ~s|<iframe src="https://example.com"></iframe><iframe src="https://other.example"></iframe>|
          ] do
        attrs = %{
          title: "Unsafe content",
          provider: "custom",
          presentation_file_id: presentation_file.id,
          content: content,
          enabled: false
        }

        assert {:error, changeset} = Embeds.create_embed(attrs)
        assert %{content: [_ | _]} = errors_on(changeset)

        assert {:error, changeset} =
                 Embeds.update_embed(presentation_file.event_id, embed, attrs)

        assert %{content: [_ | _]} = errors_on(changeset)
        assert Embeds.get_embed!(embed.id).content == embed.content
      end
    end

    test "custom embeds preserve safe single-quoted URLs and remove executable markup" do
      presentation_file = presentation_file_fixture()

      attrs = %{
        title: "Interactive content",
        provider: "custom",
        presentation_file_id: presentation_file.id,
        content: """
        <script>alert(1)</script>
        <iframe src='https://example.com/embed?a=1&amp;b=2' width='640' height='480'
          title='&quot; onload=&quot;alert(1)'
          srcdoc='<script>alert(1)</script>' onload='alert(1)' allowfullscreen
          sandbox='allow-scripts' loading='lazy' referrerpolicy='no-referrer'
          style='width:100%;height:480px;position:fixed;background:url(javascript:alert(1))'>
          <script>alert(1)</script>
        </iframe>
        """
      }

      assert {:ok, embed} = Embeds.create_embed(attrs)
      assert_safe_custom_content(embed.content)

      assert {:ok, updated} =
               Embeds.update_embed(presentation_file.event_id, embed, %{content: attrs.content})

      assert_safe_custom_content(Embeds.get_embed!(updated.id).content)
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

    test "get_embed_for_event/3 returns embed when it belongs to the event" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id})

      fetched_embed = Embeds.get_embed_for_event(embed.id, presentation_file.event_id)
      assert fetched_embed.id == embed.id
    end

    test "get_embed_for_event/3 returns nil when embed belongs to a different event" do
      presentation_file_a = presentation_file_fixture()
      presentation_file_b = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file_a.id})

      assert is_nil(Embeds.get_embed_for_event(embed.id, presentation_file_b.event_id))
    end

    test "get_embed_for_event/3 returns nil for nonexistent embed id" do
      presentation_file = presentation_file_fixture()
      assert is_nil(Embeds.get_embed_for_event(-1, presentation_file.event_id))
    end
  end

  defp assert_safe_custom_content(content) do
    document = Floki.parse_fragment!(content)
    assert [_] = Floki.find(document, "iframe")
    assert Floki.attribute(document, "iframe", "src") == ["https://example.com/embed?a=1&b=2"]
    assert Floki.attribute(document, "iframe", "width") == ["640"]
    assert Floki.attribute(document, "iframe", "height") == ["480"]
    assert Floki.attribute(document, "iframe", "title") == [~s|" onload="alert(1)|]
    assert Floki.attribute(document, "iframe", "sandbox") == ["allow-scripts"]
    assert Floki.attribute(document, "iframe", "loading") == ["lazy"]
    assert Floki.attribute(document, "iframe", "referrerpolicy") == ["no-referrer"]
    assert Floki.attribute(document, "iframe", "allowfullscreen") != []
    assert Floki.attribute(document, "iframe", "srcdoc") == []
    assert Floki.attribute(document, "iframe", "onload") == []
    assert Floki.find(document, "script") == []
    [style] = Floki.attribute(document, "iframe", "style")
    assert style =~ "width:100%"
    assert style =~ "height:480px"
    refute style =~ "position"
    refute style =~ "javascript"
  end
end
