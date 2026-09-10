defmodule ClaperWeb.EventLive.PresenterTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.PresentationsFixtures
  import Claper.PollsFixtures

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    params |> Map.put(:presentation_file, presentation_file)
  end

  describe "Poll" do
    setup [:register_and_log_in_user, :create_event]

    test "renders the average and the vote spread for a slider poll", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll_fixture(%{
        presentation_file_id: presentation_file.id,
        position: 0,
        enabled: true,
        type: :slider,
        min_value: 1,
        max_value: 3,
        min_label: "Poor",
        max_label: "Excellent",
        poll_opts: [
          %{content: "1", vote_count: 1},
          %{content: "3", vote_count: 3}
        ]
      })

      {:ok, _presenter_live, html} = live(conn, ~p"/e/#{presentation_file.event.code}/presenter")

      assert html =~ "2.5"
      assert html =~ "Average rating"
      assert html =~ "Poor"
      assert html =~ "Excellent"

      # one bar per value of the range, scaled to the most picked value
      assert html =~ ~s(style="height: 33%;")
      assert html =~ ~s(style="height: 0%;")
      assert html =~ ~s(style="height: 100%;")

      refute html =~ "25% (1)"
      refute html =~ "75% (3)"
    end

    test "renders the percentage bar list for a regular choice poll", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll_fixture(%{
        presentation_file_id: presentation_file.id,
        position: 0,
        enabled: true,
        type: :choice,
        poll_opts: [
          %{content: "yes", vote_count: 8},
          %{content: "no", vote_count: 2}
        ]
      })

      {:ok, _presenter_live, html} = live(conn, ~p"/e/#{presentation_file.event.code}/presenter")

      assert html =~ "80% (8)"
      assert html =~ "20% (2)"
    end
  end
end
