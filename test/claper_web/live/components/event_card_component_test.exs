defmodule ClaperWeb.EventCardComponentTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, EventsFixtures}

  @spec create_event(Claper.Accounts.User.t(), NaiveDateTime.t(), NaiveDateTime.t()) :: Claper.Presentations.PresentationFile.t()
  defp create_event(user, started_at, expired_at \\ nil) do
    event = event_fixture(%{user: user, started_at: started_at, expired_at: expired_at})
    presentation_file = presentation_file_fixture(%{event: event}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    presentation_file
  end

  describe "EventCardComponent" do
    setup [:register_and_log_in_user]

    test "renders incoming for future event", %{conn: conn, user: user} do
      create_event(user, NaiveDateTime.add(NaiveDateTime.utc_now(), 7200, :second))
      {:ok, _view, html} = live(conn, "/events")
      assert html =~ "Incoming"
    end

    test "renders live for current event", %{conn: conn, user: user} do
      create_event(user, NaiveDateTime.utc_now())
      {:ok, _view, html} = live(conn, "/events")
      assert html =~ "Live"
    end

    test "renders finished for expired event", %{conn: conn, user: user} do
      create_event(user, NaiveDateTime.add(NaiveDateTime.utc_now(), -7200, :second), NaiveDateTime.add(NaiveDateTime.utc_now(), -10, :second))
      {:ok, _view, html} = live(conn, "/events")
      assert html =~ "Finished"
    end

    test "renders finished for expired event before starting", %{conn: conn, user: user} do
      create_event(user, NaiveDateTime.add(NaiveDateTime.utc_now(), 7200, :second), NaiveDateTime.utc_now())
      {:ok, _view, html} = live(conn, "/events")
      assert html =~ "Finished"
    end
  end
end
