defmodule ClaperWeb.StatLive.EngagementTest do
  use ClaperWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, PostsFixtures, WordCloudsFixtures}

  setup [:register_and_log_in_user]

  setup %{user: user} do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    %{presentation_file: presentation_file, event: presentation_file.event}
  end

  test "averages distinct participants per cloud across five categories", %{
    conn: conn,
    presentation_file: presentation_file,
    event: event,
    user: user
  } do
    {:ok, _} = Claper.Stats.create_stat(event, %{user_id: user.id})
    {:ok, _} = Claper.Stats.create_stat(event, %{attendee_identifier: "guest"})

    first = word_cloud_fixture(%{presentation_file: presentation_file, enabled: false})
    second = word_cloud_fixture(%{presentation_file: presentation_file, enabled: false})

    word_cloud_entry_fixture(%{word_cloud: first, user_id: user.id, attendee_identifier: nil})

    word_cloud_entry_fixture(%{
      word_cloud: first,
      user_id: user.id,
      attendee_identifier: nil,
      content: "another word"
    })

    word_cloud_entry_fixture(%{word_cloud: first, attendee_identifier: "guest"})
    word_cloud_entry_fixture(%{word_cloud: second, attendee_identifier: "guest"})

    {:ok, view, _html} = live(conn, ~p"/events/#{event.uuid}/stats")

    # Three cloud participations / (two clouds * two attendees), weighted by one fifth.
    assert engagement_text(view) == "15%"
  end

  test "counts hidden words as participation", %{
    conn: conn,
    presentation_file: presentation_file,
    event: event
  } do
    {:ok, _} = Claper.Stats.create_stat(event, %{attendee_identifier: "guest"})
    cloud = word_cloud_fixture(%{presentation_file: presentation_file})
    {:ok, _} = Claper.WordClouds.submit_entry(event.uuid, cloud, "guest", "Hiddenword")
    {:ok, _} = Claper.WordClouds.hide_word(event.uuid, cloud, "hiddenword")

    {:ok, view, _html} = live(conn, ~p"/events/#{event.uuid}/stats")

    assert engagement_text(view) == "20%"
    refute render(view) =~ "Hiddenword"
  end

  test "reports zero without attendees even when a cloud has entries", %{
    conn: conn,
    presentation_file: presentation_file,
    event: event
  } do
    cloud = word_cloud_fixture(%{presentation_file: presentation_file})
    word_cloud_entry_fixture(%{word_cloud: cloud})

    {:ok, view, _html} = live(conn, ~p"/events/#{event.uuid}/stats")

    assert engagement_text(view) == "0%"
  end

  test "reports zero for attendees without clouds or other participation", %{
    conn: conn,
    event: event
  } do
    {:ok, _} = Claper.Stats.create_stat(event, %{attendee_identifier: "guest"})

    {:ok, view, _html} = live(conn, ~p"/events/#{event.uuid}/stats")

    assert engagement_text(view) == "0%"
  end

  test "weights messages and word clouds equally", %{
    conn: conn,
    presentation_file: presentation_file,
    event: event,
    user: user
  } do
    {:ok, _} = Claper.Stats.create_stat(event, %{user_id: user.id})
    post_fixture(%{event: event, user: user})
    cloud = word_cloud_fixture(%{presentation_file: presentation_file})
    word_cloud_entry_fixture(%{word_cloud: cloud, user_id: user.id, attendee_identifier: nil})

    {:ok, view, _html} = live(conn, ~p"/events/#{event.uuid}/stats")

    assert engagement_text(view) == "40%"
  end

  defp engagement_text(view) do
    view
    |> element("dd p", "%")
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.text()
    |> String.trim()
  end
end
