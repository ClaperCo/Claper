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

    test "renders a word cloud, sized by vote share, for a word_cloud poll", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll_fixture(%{
        presentation_file_id: presentation_file.id,
        position: 0,
        enabled: true,
        type: :word_cloud,
        poll_opts: [
          %{content: "exciting", vote_count: 8},
          %{content: "novel", vote_count: 2}
        ]
      })

      {:ok, _presenter_live, html} = live(conn, ~p"/e/#{presentation_file.event.code}/presenter")

      assert html =~ "exciting"
      assert html =~ "novel"

      exciting_size = extract_font_size(html, "exciting")
      novel_size = extract_font_size(html, "novel")

      assert exciting_size > novel_size

      refute html =~ "80% (8)"
      refute html =~ "20% (2)"
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

  defp extract_font_size(html, word) do
    [_, size] = Regex.run(~r/font-size:\s*(\d+)px"[^>]*>\s*#{word}/, html)
    String.to_integer(size)
  end
end
