defmodule ClaperWeb.EventLive.PresenterVisibilityTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PollsFixtures, PresentationsFixtures, WordCloudsFixtures}

  alias Claper.{Presentations, WordClouds}

  setup [:register_and_log_in_user]

  setup %{user: user} do
    presentation_file = presentation_file_fixture(%{user: user, length: 2}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file, poll_visible: false})
    %{presentation_file: presentation_file, event: presentation_file.event}
  end

  test "polls and wordclouds share the same presentation visibility control across slides", %{
    conn: conn,
    presentation_file: presentation_file,
    event: event
  } do
    poll_fixture(%{presentation_file_id: presentation_file.id, title: "Poll question"})

    cloud =
      word_cloud_fixture(%{
        presentation_file: presentation_file,
        position: 1,
        title: "Cloud question"
      })

    word_cloud_entry_fixture(%{word_cloud: cloud, content: "Elixir"})
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")
    toggle = ~s(#settings-modal-content button[phx-value-key="poll_visible"][phx-key="Z"])

    assert has_element?(manager, toggle <> ~s([aria-checked="false"]))
    manager |> element(toggle) |> render_keydown()
    assert presentation_state(presentation_file).poll_visible

    {:ok, _} =
      Presentations.update_presentation_state(presentation_state(presentation_file), %{
        position: 1
      })

    assert has_element?(presenter, "#word-cloud h2", cloud.title)
    assert has_element?(manager, toggle <> ~s([aria-checked="true"]))

    manager |> element(toggle) |> render_keydown()
    refute presentation_state(presentation_file).poll_visible
    assert WordClouds.get_word_cloud!(cloud.id).show_results

    {:ok, _} =
      Presentations.update_presentation_state(presentation_state(presentation_file), %{
        position: 0
      })

    assert has_element?(presenter, "#poll", "Poll question")
    assert has_element?(manager, toggle <> ~s([aria-checked="false"]))
    {:ok, reloaded, _html} = live(conn, ~p"/e/#{event.code}/manage")
    assert has_element?(reloaded, toggle <> ~s([aria-checked="false"]))
  end

  test "wordcloud presentation visibility never changes audience visibility or submissions", %{
    conn: conn,
    presentation_file: presentation_file,
    event: event
  } do
    cloud =
      word_cloud_fixture(%{presentation_file: presentation_file, title: "Audience question"})

    {:ok, _} = WordClouds.submit_entry(event.uuid, cloud, "first", "Elixir")
    {:ok, _} = WordClouds.submit_entry(event.uuid, cloud, "second", "Hiddenword")
    {:ok, cloud} = WordClouds.hide_word(event.uuid, cloud, "hiddenword")
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")
    {:ok, attendee, _html} = live(build_conn(), ~p"/e/#{event.code}")
    toggle = ~s(#settings-modal-content button[phx-value-key="poll_visible"][phx-key="Z"])

    assert word_cloud_names(render(attendee)) == ["Elixir"]
    manager |> element(toggle) |> render_keydown()
    assert presentation_state(presentation_file).poll_visible
    assert presenter_words(presenter, cloud) == ["Elixir"]

    manager |> element(toggle) |> render_keydown()
    refute presentation_state(presentation_file).poll_visible
    attendee |> form(~s(form[phx-submit="submit-word"]), %{word: "Phoenix"}) |> render_submit()
    assert word_cloud_names(render(attendee)) == ["Elixir", "Phoenix"]
    send(presenter.pid, {:word_cloud_entry_added, cloud})
    send(presenter.pid, {:current_interaction, cloud})
    refute presentation_state(presentation_file).poll_visible

    manager |> element(toggle) |> render_keydown()
    assert presenter_words(presenter, cloud) == ["Elixir", "Phoenix"]
    refute render(presenter) =~ "Hiddenword"

    render_hook(manager, "checked", %{"key" => "word_cloud_show_results", "value" => false})
    refute has_element?(attendee, "[phx-hook=WordCloud]")
    assert presentation_state(presentation_file).poll_visible
    assert presenter_words(presenter, cloud) == ["Elixir", "Phoenix"]
  end

  defp presentation_state(presentation_file) do
    Presentations.get_presentation_file!(presentation_file.id, [:presentation_state]).presentation_state
  end

  defp presenter_words(view, cloud) do
    view |> element("#word-cloud-#{cloud.id}-words") |> render() |> word_cloud_names()
  end
end
