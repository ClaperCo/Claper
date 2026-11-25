defmodule ClaperWeb.EventLive.QuizReviewTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, QuizzesFixtures}

  setup [:register_and_log_in_user]

  setup %{user: user} do
    presentation_file = presentation_file_fixture(%{user: user, length: 2}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    quiz =
      quiz_fixture(%{
        presentation_file: presentation_file,
        position: 0,
        enabled: true,
        show_results: true
      })

    %{event: presentation_file.event, quiz: quiz}
  end

  @review ~s(#settings-modal-content button[phx-value-key="quiz_review"])
  @next ~s(#settings-modal-content button[phx-value-key="next_quiz_question"])
  @prev ~s(#settings-modal-content button[phx-value-key="prev_quiz_question"])

  # The manager's command reaches the presenter, whose answer reaches the
  # manager again; rendering both views in this order waits for the round trip.
  defp settle(manager, presenter) do
    render(presenter)
    render(manager)
  end

  test "review questions is a switch that can be turned off again", %{
    conn: conn,
    event: event,
    quiz: quiz
  } do
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")

    assert has_element?(manager, @review <> ~s([aria-checked="false"]))
    assert has_element?(manager, @review <> ~s([phx-key="C"]))
    assert has_element?(manager, @prev <> "[disabled]")
    assert has_element?(manager, @next <> "[disabled]")
    assert has_element?(presenter, "##{quiz.id}-quiz", quiz.title)

    render_hook(manager, "checked", %{"key" => "quiz_review", "value" => true})
    settle(manager, presenter)

    assert has_element?(manager, @review <> ~s([aria-checked="true"]))
    refute has_element?(manager, @next <> "[disabled]")
    refute has_element?(manager, @prev <> "[disabled]")
    assert has_element?(presenter, "##{quiz.id}-quiz", "some question content")

    render_hook(manager, "checked", %{"key" => "quiz_review", "value" => false})
    settle(manager, presenter)

    assert has_element?(manager, @review <> ~s([aria-checked="false"]))
    assert has_element?(manager, @next <> "[disabled]")
    assert has_element?(presenter, "##{quiz.id}-quiz", quiz.title)
  end

  test "going past the last question ends the review", %{conn: conn, event: event} do
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")

    render_hook(manager, "checked", %{"key" => "quiz_review", "value" => true})
    settle(manager, presenter)
    assert has_element?(manager, @review <> ~s([aria-checked="true"]))

    # The quiz has a single question, so "next" leaves the review.
    render_hook(manager, "checked", %{"key" => "next_quiz_question"})
    settle(manager, presenter)
    assert has_element?(manager, @review <> ~s([aria-checked="false"]))
  end
end
