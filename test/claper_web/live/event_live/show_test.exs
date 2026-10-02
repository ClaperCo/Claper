defmodule ClaperWeb.EventLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{AccountsFixtures, PostsFixtures, PresentationsFixtures, ScalesFixtures}

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

  describe "slider" do
    setup %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])
      presentation_state_fixture(%{presentation_file: presentation_file})

      %{presentation_file: presentation_file, event: presentation_file.event}
    end

    @answer_form ~s(form[phx-submit="submit-scale"])

    test "an anonymous attendee answers and then sees the results", %{
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file)
      scale_response_fixture(%{scale: scale, value: 2, attendee_identifier: "someone"})

      {:ok, view, html} = live(build_conn(), ~p"/e/#{event.code}")

      assert html =~ "How sure are you?"
      assert has_element?(view, ~s(#{@answer_form} input[type="range"][min="1"][max="10"]))
      refute has_element?(view, "##{scale.id}-scale-results")

      view |> form(@answer_form, %{value: "8"}) |> render_submit()

      refute has_element?(view, @answer_form)
      assert has_element?(view, "[data-answered]", "8")
      assert has_element?(view, "##{scale.id}-scale-results dd", "5")

      assert [_someone, %{value: 8, attendee_identifier: identifier, user_id: nil}] =
               Claper.Scales.list_responses(scale.id)

      assert is_binary(identifier)
    end

    test "a signed-in attendee's answer is stored under their account", %{
      conn: conn,
      user: user,
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file)
      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")

      view |> form(@answer_form, %{value: "3"}) |> render_submit()

      assert [%{value: 3, user_id: user_id, attendee_identifier: nil}] =
               Claper.Scales.list_responses(scale.id)

      assert user_id == user.id
    end

    test "an attendee who answered earlier sees their answer after a reload", %{
      conn: conn,
      user: user,
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file)
      {:ok, _} = Claper.Scales.submit_response(event.uuid, scale, user.id, "6")

      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")

      refute has_element?(view, @answer_form)
      assert has_element?(view, "[data-answered]", "6")
    end

    test "the slider starts in the middle and shows the chosen value", %{
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file, %{min_value: 0, max_value: 10, step: 2})
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")
      shown = "##{scale.id}-scale-form p.text-3xl"

      assert has_element?(view, shown, "4")

      view |> form(@answer_form, %{value: "8"}) |> render_change()
      assert has_element?(view, shown, "8")

      render_hook(view, "scale-select", %{"value" => "7"})
      render_hook(view, "scale-select", %{"value" => "40"})
      assert has_element?(view, shown, "8")
    end

    test "the results stay out of the markup while attendees may not see them", %{
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file, %{show_results: false})
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      view |> form(@answer_form, %{value: "8"}) |> render_submit()

      assert has_element?(view, "[data-answered]", "8")
      refute has_element?(view, "##{scale.id}-scale-results")
    end

    test "the results follow answers from other attendees", %{
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      view |> form(@answer_form, %{value: "8"}) |> render_submit()
      {:ok, _} = Claper.Scales.submit_response(event.uuid, scale, "someone else", "4")

      assert has_element?(view, "##{scale.id}-scale-results dd", "6")
      assert has_element?(view, "##{scale.id}-scale-results dd", "2")
    end

    test "a value off the range or between two points is refused with a message", %{
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file, %{min_value: 0, max_value: 10, step: 2})
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      for value <- ["12", "-2", "3", "4.0", "four"] do
        assert render_hook(view, "submit-scale", %{"value" => value}) =~
                 "Please pick a value on the slider."
      end

      assert Claper.Scales.list_responses(scale.id) == []
      assert has_element?(view, @answer_form)
    end

    test "a second answer is refused", %{
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      view |> form(@answer_form, %{value: "8"}) |> render_submit()

      assert render_hook(view, "submit-scale", %{"value" => "2"}) =~ "You have already answered."
      assert [%{value: 8}] = Claper.Scales.list_responses(scale.id)
    end

    test "a slider id sent by the client is ignored", %{
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file)
      foreign = scale_fixture(%{title: "Foreign"})
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      render_hook(view, "submit-scale", %{"value" => "5", "id" => foreign.id})

      assert Claper.Scales.list_responses(foreign.id) == []
      assert [%{value: 5}] = Claper.Scales.list_responses(scale.id)
    end

    test "a slider that was closed meanwhile takes no answer", %{
      presentation_file: presentation_file,
      event: event
    } do
      scale = open_scale(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      {:ok, _} = Claper.Scales.set_disabled(scale.id)
      render_hook(view, "submit-scale", %{"value" => "5"})

      assert Claper.Scales.list_responses(scale.id) == []
      refute has_element?(view, @answer_form)
    end

    test "an answer without a current slider is ignored", %{event: event} do
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      render_hook(view, "submit-scale", %{"value" => "5"})
      render_hook(view, "scale-select", %{"value" => "5"})

      assert Process.alive?(view.pid)
    end
  end

  defp open_scale(presentation_file, attrs \\ %{}) do
    scale_fixture(
      Map.merge(%{presentation_file: presentation_file, title: "How sure are you?"}, attrs)
    )
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end
end
