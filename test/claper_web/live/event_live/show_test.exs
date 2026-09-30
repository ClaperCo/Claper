defmodule ClaperWeb.EventLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{AccountsFixtures, PostsFixtures, PresentationsFixtures, WordCloudsFixtures}

  setup [:register_and_log_in_user]

  test "renders the fixed attendee room stack and identity menu", %{
    conn: conn,
    user: user
  } do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert "h-[100dvh]" in classes(document, "#attendee-room")
    assert "grid-rows-[auto_auto_minmax(0,1fr)]" in classes(document, "#attendee-room")
    assert "z-[60]" in classes(document, "#side-menu")
    assert "h-[40dvh]" in classes(document, "#focus-slot")
    assert Floki.find(document, "#focus-media img") != []
    assert Floki.find(document, "[data-focus-collapse]") != []
    assert Floki.find(document, "[data-focus-show]") != []
    assert document |> Floki.find("[data-focus-show]") |> Floki.text() =~ "Show presentation"
    assert "overflow-y-auto" in classes(document, "#chat-feed")
    assert Floki.attribute(document, "#chat-feed", "phx-hook") == ["RoomFeed"]
    assert Floki.attribute(document, "#post-form", "phx-hook") == ["PostForm"]
    assert "attendee-composer" in classes(document, "#post-form")
    assert Floki.find(document, "#room-topbar") != []
    assert Floki.find(document, "#room-composer") != []
    assert Floki.attribute(document, "[data-reaction-icon]", "draggable") == ["false"]
    assert "pointer-events-none" in classes(document, "[data-reaction-icon]")
    assert Floki.find(document, "#top-identity-button") == []
    assert Floki.find(document, "#composer-identity-button") != []

    [close_command] = Floki.attribute(document, "#nicknamepicker", "data-close")

    assert [["hide", %{"to" => "#identity-menu"}]] = Jason.decode!(close_command)
    assert Floki.attribute(document, "#nicknamepicker", "phx-click") == []
  end

  test "updates reaction controls when message reactions are enabled", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])

    state =
      presentation_state_fixture(%{
        presentation_file: presentation_file,
        message_reaction_enabled: false
      })

    post_fixture(%{event: presentation_file.event, user: user_fixture()})

    {:ok, view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    refute html =~ "data-message-reaction-trigger"

    send(view.pid, {:state_updated, %{state | message_reaction_enabled: true}})

    assert render(view) =~ "data-message-reaction-trigger"
  end

  test "does not render the focus panel without attendee content", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user, length: 0}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert Floki.find(document, "#focus-slot") == []
    assert "grid-rows-[auto_minmax(0,1fr)]" in classes(document, "#attendee-room")
    refute html =~ "Waiting for content"
  end

  test "renders attendee captions as a collapsible panel that cannot be disabled", %{
    conn: conn,
    user: user
  } do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    {:ok, _config} =
      Claper.Transcriptions.create_transcription_config(%{
        presentation_file_id: presentation_file.id,
        enabled: true,
        visibility: "attendee"
      })

    {:ok, view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert "grid-rows-[auto_auto_auto_minmax(0,1fr)]" in classes(document, "#attendee-room")
    assert Floki.attribute(document, "#caption-panel", "phx-hook") == ["AttendeeCaptions"]
    assert Floki.find(document, "[data-caption-collapse]") != []
    assert Floki.find(document, "[data-caption-show]") != []
    assert Floki.find(document, "[data-caption-toggle]") == []
    assert document |> Floki.find("[data-caption-show]") |> Floki.text() =~ "Show captions"

    send(view.pid, {:transcription_delta, "Live caption text"})

    assert view
           |> render()
           |> Floki.parse_document!()
           |> Floki.find("[data-caption-text]")
           |> Floki.text() =~ "Live caption text"
  end

  describe "word cloud" do
    setup %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])
      presentation_state_fixture(%{presentation_file: presentation_file})

      %{presentation_file: presentation_file, event: presentation_file.event}
    end

    test "an anonymous attendee sends a word and then sees the cloud", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      word_cloud_entry_fixture(%{word_cloud: word_cloud, content: "Quokka"})

      {:ok, view, html} = live(build_conn(), ~p"/e/#{event.code}")

      assert html =~ "One word"
      assert has_element?(view, ~s(form[phx-submit="submit-word"] input[name="word"]))
      refute html =~ "Quokka"

      view
      |> form(~s(form[phx-submit="submit-word"]), %{word: "  Elixir "})
      |> render_submit()

      refute has_element?(view, ~s(form[phx-submit="submit-word"]))
      assert has_element?(view, "[data-submitted]")
      assert attendee_cloud(view, word_cloud) == ["Elixir", "Quokka"]

      assert [_quokka, %{content: "Elixir", attendee_identifier: identifier, user_id: nil}] =
               Claper.WordClouds.list_entries(word_cloud.id)

      assert is_binary(identifier)
    end

    test "a signed-in attendee's word is stored under their account", %{
      conn: conn,
      user: user,
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)

      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")

      view
      |> form(~s(form[phx-submit="submit-word"]), %{word: "Elixir"})
      |> render_submit()

      assert [%{user_id: user_id, attendee_identifier: nil}] =
               Claper.WordClouds.list_entries(word_cloud.id)

      assert user_id == user.id
    end

    test "the cloud is left out of the markup while attendees may not see it", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file, %{show_results: false})
      word_cloud_entry_fixture(%{word_cloud: word_cloud, content: "Zanzibar"})

      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      html =
        view
        |> form(~s(form[phx-submit="submit-word"]), %{word: "Mine"})
        |> render_submit()

      assert html =~ "Mine"
      refute html =~ "Zanzibar"
      refute has_element?(view, "##{word_cloud.id}-word-cloud-cloud")
    end

    test "a hidden word is left out of the attendee's cloud", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      word_cloud_entry_fixture(%{word_cloud: word_cloud, content: "Grumpfwort"})
      {:ok, _} = Claper.WordClouds.hide_word(event.uuid, word_cloud, "grumpfwort")

      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      html =
        view
        |> form(~s(form[phx-submit="submit-word"]), %{word: "Kind"})
        |> render_submit()

      assert attendee_cloud(view, word_cloud) == ["Kind"]
      refute html =~ "Grumpfwort"
    end

    test "the cloud follows words other attendees send", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      view
      |> form(~s(form[phx-submit="submit-word"]), %{word: "Elixir"})
      |> render_submit()

      {:ok, _} = Claper.WordClouds.submit_entry(event.uuid, word_cloud, "someone else", "Erlang")

      assert attendee_cloud(view, word_cloud) == ["Elixir", "Erlang"]
    end

    test "an attendee can send as many words as the cloud allows", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file, %{max_entries: 2})
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      html =
        view
        |> form(~s(form[phx-submit="submit-word"]), %{word: "Elixir"})
        |> render_submit()

      assert html =~ "You can send one more word."

      html =
        view
        |> form(~s(form[phx-submit="submit-word"]), %{word: "ELIXIR"})
        |> render_submit()

      assert html =~ "You have already sent this word."

      view
      |> form(~s(form[phx-submit="submit-word"]), %{word: "Erlang"})
      |> render_submit()

      refute has_element?(view, ~s(form[phx-submit="submit-word"]))

      assert render_hook(view, "submit-word", %{"word" => "Gleam"}) =~
               "You have already sent your 2 words."

      assert length(Claper.WordClouds.list_entries(word_cloud.id)) == 2
    end

    test "a blank word is refused with a message", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      assert render_hook(view, "submit-word", %{"word" => "   "}) =~
               "Your word could not be added. Please type a word or a short phrase."

      assert Claper.WordClouds.list_entries(word_cloud.id) == []
    end

    test "a word longer than a column holds is refused with a message", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")
      word = "a" <> String.duplicate("\u0301", 300)

      assert render_hook(view, "submit-word", %{"word" => word}) =~
               "Your word could not be added. Please type a word or a short phrase."

      assert Claper.WordClouds.list_entries(word_cloud.id) == []
    end

    test "a short word whose key outgrows its column is refused with a message", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      assert render_hook(view, "submit-word", %{"word" => String.duplicate("\uFDFA", 15)}) =~
               "Your word could not be added. Please type a word or a short phrase."

      assert Claper.WordClouds.list_entries(word_cloud.id) == []
    end

    test "a word cloud that was closed meanwhile takes no words", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      {:ok, _} = Claper.WordClouds.set_disabled(word_cloud.id)
      render_hook(view, "submit-word", %{"word" => "Elixir"})

      assert Claper.WordClouds.list_entries(word_cloud.id) == []
      refute has_element?(view, ~s(form[phx-submit="submit-word"]))
    end
  end

  defp open_word_cloud(presentation_file, attrs \\ %{}) do
    word_cloud_fixture(
      Map.merge(%{presentation_file: presentation_file, title: "One word"}, attrs)
    )
  end

  defp attendee_cloud(view, word_cloud) do
    view
    |> element("##{word_cloud.id}-word-cloud-cloud")
    |> render()
    |> word_cloud_names()
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end
end
