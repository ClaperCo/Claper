defmodule ClaperWeb.PollLive.FormComponentTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.PollsFixtures
  import Claper.PresentationsFixtures

  alias Claper.Polls

  @word_cloud_hint "Attendees type their own word or short phrase"

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    Map.put(params, :presentation_file, presentation_file)
  end

  describe "new poll" do
    setup [:register_and_log_in_user, :create_event]

    test "starts on Choice, with the option inputs and the multiple-answers checkbox", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage/add/poll")

      assert option_contents(html) == ["Yes", "No"]
      assert multiple_checkbox?(html)
      refute html =~ @word_cloud_hint
    end

    test "choosing Word Cloud hides the options and the multiple-answers checkbox", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage/add/poll")

      html =
        view
        |> form("#poll-form", poll: %{"title" => "One word?", "type" => "word_cloud"})
        |> render_change()

      assert html =~ @word_cloud_hint
      assert option_contents(html) == []
      refute multiple_checkbox?(html)
    end

    test "creates a word cloud poll from a title alone, with no options", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage/add/poll")

      view
      |> form("#poll-form", poll: %{"title" => "One word?", "type" => "word_cloud"})
      |> render_change()

      view |> form("#poll-form", poll: %{}) |> render_submit()

      assert [poll] = Polls.list_polls(presentation_file.id)
      assert poll.title == "One word?"
      assert poll.type == :word_cloud
      assert poll.poll_opts == []
    end
  end

  describe "edit poll" do
    setup [:register_and_log_in_user, :create_event]

    test "keeps the word cloud layout after a change event on a saved word cloud", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: [%{content: "tired", vote_count: 1}]
        })

      {:ok, view, html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      assert html =~ @word_cloud_hint

      html = view |> form("#poll-form", poll: %{"show_results" => "true"}) |> render_change()

      assert html =~ @word_cloud_hint
      assert option_contents(html) == []
      refute multiple_checkbox?(html)
    end

    test "switching an unanswered choice poll to Word Cloud drops the options it no longer uses",
         %{conn: conn, presentation_file: presentation_file} do
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})

      {:ok, view, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      view |> form("#poll-form", poll: %{"type" => "word_cloud"}) |> render_change()
      view |> form("#poll-form", poll: %{}) |> render_submit()

      saved = Polls.get_poll!(poll.id)

      assert saved.type == :word_cloud
      assert saved.poll_opts == []
    end

    test "says why an answered choice poll cannot become a word cloud, and keeps the votes", %{
      conn: conn,
      presentation_file: presentation_file,
      user: user
    } do
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})
      [poll_opt | _] = poll.poll_opts
      {:ok, _} = Polls.vote(user.id, presentation_file.event_id, [poll_opt], poll.id)

      {:ok, view, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      html = view |> form("#poll-form", poll: %{"type" => "word_cloud"}) |> render_change()

      assert html =~ "cannot be changed once this poll has been answered"

      view |> form("#poll-form", poll: %{}) |> render_submit()

      saved = Polls.get_poll!(poll.id)

      assert saved.type == :choice
      assert Enum.map(saved.poll_opts, & &1.content) == ["some option 1", "some option 2"]
      assert Claper.Repo.aggregate(Claper.Polls.PollVote, :count) == 1
    end

    test "says why a word cloud that holds words cannot become a choice poll", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: [%{content: "tired", vote_count: 2}]
        })

      {:ok, view, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      html = view |> form("#poll-form", poll: %{"type" => "choice"}) |> render_change()

      assert html =~ "cannot be changed once this poll has been answered"

      view |> form("#poll-form", poll: %{}) |> render_submit()

      saved = Polls.get_poll!(poll.id)

      assert saved.type == :word_cloud
      assert [%{content: "tired", vote_count: 2}] = saved.poll_opts
    end

    test "does not open a choice poll's form with the missing-choices message already in red", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})

      # A choice poll whose last option went elsewhere: the form still opens on
      # what the presenter has, not on a complaint about it.
      Claper.Repo.delete_all(Claper.Polls.PollOpt)

      {:ok, _view, html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      refute html =~ "Add at least one choice for this poll."
    end

    test "shows why an unanswered word cloud cannot be turned back into a choice poll", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: []
        })

      {:ok, view, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/edit/poll/#{poll.id}")

      view |> form("#poll-form", poll: %{"type" => "choice"}) |> render_change()
      html = view |> form("#poll-form", poll: %{}) |> render_submit()

      assert html =~ "Add at least one choice for this poll."
      assert Polls.get_poll!(poll.id).type == :word_cloud

      # and a screen reader is told the same thing, not just a red line
      document = Floki.parse_document!(html)

      assert [group] = Floki.find(document, ~s{#poll-form [role="group"]})
      assert Floki.attribute(group, "aria-invalid") == ["true"]
      assert Floki.attribute(group, "aria-describedby") == ["poll-poll-opts-error"]

      assert document
             |> Floki.find("#poll-poll-opts-error")
             |> Floki.text() =~ "Add at least one choice for this poll."

      # and the way out of that message is right there in the form
      html = view |> element("#poll-form button[phx-click=add_opt]") |> render_click()
      assert option_contents(html) == [""]

      view
      |> form("#poll-form", poll: %{"poll_opts" => %{"0" => %{"content" => "Yes"}}})
      |> render_submit()

      saved = Polls.get_poll!(poll.id)

      assert saved.type == :choice
      assert Enum.map(saved.poll_opts, & &1.content) == ["Yes"]
    end
  end

  defp option_contents(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(~s{input[name^="poll[poll_opts]"][name$="[content]"]})
    |> Enum.map(fn input -> input |> Floki.attribute("value") |> List.first() || "" end)
  end

  defp multiple_checkbox?(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(~s{input[type="checkbox"][name="poll[multiple]"]}) != []
  end
end
