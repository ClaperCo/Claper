defmodule ClaperWeb.TranscriptionLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.PresentationsFixtures

  alias Claper.Transcriptions

  setup [:register_and_log_in_user]

  setup %{user: user} do
    {:ok, _} = Claper.Settings.set("transcription_enabled", "false")

    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    other_presentation_file = presentation_file_fixture(%{}, [:event])

    {:ok, other_config} =
      Transcriptions.create_transcription_config(%{
        presentation_file_id: other_presentation_file.id,
        enabled: true,
        language: "fr"
      })

    %{presentation_file: presentation_file, other_config: other_config}
  end

  test "rejects disabling another owner's transcription", %{
    conn: conn,
    presentation_file: presentation_file,
    other_config: other_config
  } do
    {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

    render_click(manage_live, "transcription-set-inactive", %{"id" => other_config.id})

    assert Transcriptions.get_transcription_config(other_config.presentation_file_id).enabled
    assert render(manage_live) =~ "Resource not found"
  end

  test "cannot move a transcription config into another owner's event while editing", %{
    conn: conn,
    presentation_file: presentation_file
  } do
    {:ok, config} =
      Transcriptions.create_transcription_config(%{
        presentation_file_id: presentation_file.id,
        language: "en"
      })

    other_presentation_file = presentation_file_fixture()

    {:ok, manage_live, _html} =
      live(
        conn,
        ~p"/e/#{presentation_file.event.code}/manage/edit/transcription/#{config.id}"
      )

    manage_live
    |> form("#transcription-config-form", transcription_config: %{language: "de"})
    |> render_submit(%{
      "transcription_config" => %{"presentation_file_id" => other_presentation_file.id}
    })

    assert %{id: config_id, language: "de"} =
             Transcriptions.get_transcription_config(presentation_file.id)

    assert config_id == config.id
    assert Transcriptions.get_transcription_config(other_presentation_file.id) == nil
  end

  test "rejects enabling another owner's transcription without broadcasting its config", %{
    conn: conn,
    presentation_file: presentation_file,
    other_config: other_config
  } do
    {:ok, other_config} = Transcriptions.set_transcription_disabled(other_config)
    {:ok, _} = Claper.Settings.set("transcription_enabled", "true")
    Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{presentation_file.event.uuid}")

    {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

    render_click(manage_live, "transcription-set-active", %{
      "id" => Integer.to_string(other_config.id)
    })

    refute Transcriptions.get_transcription_config(other_config.presentation_file_id).enabled
    assert Transcriptions.get_transcription_config(presentation_file.id) == nil
    assert render(manage_live) =~ "Resource not found"
    refute Claper.Transcriptions.TranscriptionWorker.running?(presentation_file.event.uuid)
    refute_receive {:transcription_config_updated, _}
  end

  test "rejects opening another owner's transcription editor", %{
    conn: conn,
    presentation_file: presentation_file,
    other_config: other_config
  } do
    {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

    render_patch(
      manage_live,
      ~p"/e/#{presentation_file.event.code}/manage/edit/transcription/#{other_config.id}"
    )

    assert_redirect(manage_live, ~p"/e/#{presentation_file.event.code}/manage")

    assert Transcriptions.get_transcription_config(other_config.presentation_file_id) ==
             other_config
  end

  test "rejects foreign and nonexistent ids submitted to the delete component", %{
    conn: conn,
    presentation_file: presentation_file,
    other_config: other_config
  } do
    config = transcription_config_fixture(presentation_file)

    for id <- [other_config.id, -1] do
      {:ok, manage_live, _html} =
        live(
          conn,
          ~p"/e/#{presentation_file.event.code}/manage/edit/transcription/#{config.id}"
        )

      manage_live
      |> element(~s(#transcription-config-form a[phx-click="delete"]))
      |> render_click(%{"id" => Integer.to_string(id)})

      assert_redirect(manage_live, ~p"/e/#{presentation_file.event.code}/manage")
      assert Transcriptions.get_transcription_config(presentation_file.id) == config

      assert Transcriptions.get_transcription_config(other_config.presentation_file_id) ==
               other_config
    end
  end

  test "an owner can disable, edit and delete their own transcription", %{
    conn: conn,
    presentation_file: presentation_file,
    other_config: other_config
  } do
    config = transcription_config_fixture(presentation_file, %{enabled: true, language: "en"})
    {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

    render_click(manage_live, "transcription-set-inactive", %{"id" => config.id})

    refute Transcriptions.get_transcription_config(presentation_file.id).enabled
    assert_push_event(manage_live, "transcription-state", %{enabled: false})

    render_patch(
      manage_live,
      ~p"/e/#{presentation_file.event.code}/manage/edit/transcription/#{config.id}"
    )

    manage_live
    |> form("#transcription-config-form",
      transcription_config: %{language: "de", visibility: "attendee"}
    )
    |> render_submit()

    assert %{language: "de", visibility: "attendee"} =
             Transcriptions.get_transcription_config(presentation_file.id)

    {:ok, manage_live, _html} =
      live(
        conn,
        ~p"/e/#{presentation_file.event.code}/manage/edit/transcription/#{config.id}"
      )

    manage_live
    |> element(~s(#transcription-config-form a[phx-click="delete"]))
    |> render_click()

    assert_redirect(manage_live, ~p"/e/#{presentation_file.event.code}/manage")
    assert Transcriptions.get_transcription_config(presentation_file.id) == nil

    assert Transcriptions.get_transcription_config(other_config.presentation_file_id) ==
             other_config
  end

  test "a leader can disable their event's transcription but not another owner's", %{
    presentation_file: presentation_file,
    other_config: other_config
  } do
    leader = Claper.AccountsFixtures.confirmed_user_fixture()
    Claper.EventsFixtures.activity_leader_fixture(%{event: presentation_file.event, user: leader})
    conn = build_conn() |> log_in_user(leader)
    config = transcription_config_fixture(presentation_file, %{enabled: true})

    {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

    render_click(manage_live, "transcription-set-inactive", %{"id" => other_config.id})

    assert Transcriptions.get_transcription_config(other_config.presentation_file_id).enabled
    assert render(manage_live) =~ "Resource not found"

    render_click(manage_live, "transcription-set-inactive", %{"id" => config.id})

    refute Transcriptions.get_transcription_config(presentation_file.id).enabled
  end

  test "rejects nonexistent config ids for both transcription toggles", %{
    conn: conn,
    presentation_file: presentation_file,
    other_config: other_config
  } do
    {:ok, _} = Claper.Settings.set("transcription_enabled", "true")
    {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

    for action <- ["transcription-set-active", "transcription-set-inactive"] do
      render_click(manage_live, action, %{"id" => "-1"})
      assert render(manage_live) =~ "Resource not found"
    end

    assert Transcriptions.get_transcription_config(presentation_file.id) == nil

    assert Transcriptions.get_transcription_config(other_config.presentation_file_id) ==
             other_config
  end

  test "creating a config ignores a foreign presentation id and forced activation", %{
    conn: conn,
    presentation_file: presentation_file,
    other_config: other_config
  } do
    {:ok, manage_live, _html} =
      live(conn, ~p"/e/#{presentation_file.event.code}/manage/add/transcription")

    manage_live
    |> form("#transcription-config-form", transcription_config: %{language: "en"})
    |> render_submit(%{
      "transcription_config" => %{
        "presentation_file_id" => other_config.presentation_file_id,
        "enabled" => "true"
      }
    })

    assert %{language: "en", enabled: false} =
             Transcriptions.get_transcription_config(presentation_file.id)

    assert Transcriptions.get_transcription_config(other_config.presentation_file_id) ==
             other_config
  end

  test "an owner cannot enable transcription while it is globally disabled", %{
    conn: conn,
    presentation_file: presentation_file
  } do
    config = transcription_config_fixture(presentation_file)
    {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

    render_click(manage_live, "transcription-set-active", %{"id" => config.id})

    refute Transcriptions.get_transcription_config(presentation_file.id).enabled
    assert render(manage_live) =~ "Transcription has been disabled by the administrator"
  end

  defp transcription_config_fixture(presentation_file, attrs \\ %{}) do
    {:ok, config} =
      attrs
      |> Map.put(:presentation_file_id, presentation_file.id)
      |> Transcriptions.create_transcription_config()

    config
  end
end
