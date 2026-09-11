defmodule ClaperWeb.PollLive.FormComponentTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.PresentationsFixtures
  import Claper.PollsFixtures

  alias Claper.Polls

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    params |> Map.put(:presentation_file, presentation_file)
  end

  defp slider_poll(presentation_file, attrs \\ %{}) do
    poll_fixture(
      Map.merge(
        %{
          presentation_file_id: presentation_file.id,
          title: "rate it",
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        },
        attrs
      )
    )
  end

  describe "editing a slider poll" do
    setup [:register_and_log_in_user, :create_event]

    test "keeps the range fields on screen while the form validates", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll = slider_poll(presentation_file)

      {:ok, view, html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      assert html =~ "Lowest value"
      refute html =~ "Multiple answers"

      html =
        view
        |> form("#poll-form", %{
          "poll" => %{
            "title" => "rate it!",
            "type" => "slider",
            "min_value" => "1",
            "max_value" => "10"
          }
        })
        |> render_change()

      assert html =~ "Lowest value"
      assert html =~ "Highest value"
      refute html =~ "Multiple answers"
    end

    test "saves a new range after the form has validated", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll = slider_poll(presentation_file)

      {:ok, view, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      view
      |> form("#poll-form", %{"poll" => %{"title" => "rate it!"}})
      |> render_change()

      view
      |> form("#poll-form", %{
        "poll" => %{
          "title" => "rate it!",
          "type" => "slider",
          "min_value" => "2",
          "max_value" => "6"
        }
      })
      |> render_submit()

      poll = Polls.get_poll!(poll.id)
      assert poll.type == :slider
      assert poll.min_value == 2
      assert poll.max_value == 6
    end
  end

  describe "narrowing the range of a slider poll that has been rated" do
    setup [:register_and_log_in_user, :create_event]

    test "shows the error instead of dropping the ratings left outside", %{
      conn: conn,
      presentation_file: presentation_file,
      user: user
    } do
      poll = slider_poll(presentation_file)
      {:ok, _} = Polls.submit_rating(user.id, presentation_file.event.uuid, poll.id, "8")

      {:ok, view, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      html =
        view
        |> form("#poll-form", %{
          "poll" => %{
            "title" => "rate it",
            "type" => "slider",
            "min_value" => "1",
            "max_value" => "5"
          }
        })
        |> render_submit()

      assert html =~ "cannot leave out ratings that have already been submitted"

      poll = Polls.get_poll!(poll.id)
      assert poll.max_value == 10
      assert Enum.map(poll.poll_opts, & &1.rating_value) == [8]
    end
  end

  describe "switching a saved slider poll back to a choice poll" do
    setup [:register_and_log_in_user, :create_event]

    test "offers empty choices instead of the attendees' ratings", %{
      conn: conn,
      presentation_file: presentation_file,
      user: user
    } do
      poll = slider_poll(presentation_file)
      {:ok, _} = Polls.submit_rating(user.id, presentation_file.event.uuid, poll.id, "7")

      {:ok, view, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      html =
        view
        |> form("#poll-form", %{"poll" => %{"type" => "choice"}})
        |> render_change()

      assert html =~ "Choice 1"
      refute html =~ ~s(value="7")
    end

    test "shows the error when the presenter saves it without any choice", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll = slider_poll(presentation_file)

      {:ok, view, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      view
      |> form("#poll-form", %{"poll" => %{"type" => "choice"}})
      |> render_change()

      html =
        view
        |> form("#poll-form", %{"poll" => %{"type" => "choice"}})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert Polls.get_poll!(poll.id).type == :slider
    end
  end
end
