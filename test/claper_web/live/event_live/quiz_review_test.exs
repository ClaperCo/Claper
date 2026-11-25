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
    assert has_element?(presenter, "##{quiz.id}-quiz", quiz.title)

    render_hook(manager, "checked", %{"key" => "quiz_review", "value" => true})
    settle(manager, presenter)

    assert has_element?(manager, @review <> ~s([aria-checked="true"]))
    assert has_element?(presenter, "##{quiz.id}-quiz", "some question content")

    render_hook(manager, "checked", %{"key" => "quiz_review", "value" => false})
    settle(manager, presenter)

    assert has_element?(manager, @review <> ~s([aria-checked="false"]))
    assert has_element?(presenter, "##{quiz.id}-quiz", quiz.title)
  end

  test "previous and next only show while reviewing a quiz with several questions", %{
    conn: conn,
    event: event,
    quiz: single
  } do
    # One question: nothing to step through, with or without a review.
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")
    render_hook(manager, "checked", %{"key" => "quiz_review", "value" => true})
    settle(manager, presenter)
    refute has_element?(manager, @next)
    refute has_element?(manager, @prev)

    # Several questions: the buttons belong to the review.
    {:ok, _} = Claper.Quizzes.update_quiz(event.uuid, single, %{enabled: false})
    question = fn n ->
      %{
        content: "question #{n}",
        type: "qcm",
        quiz_question_opts: [
          %{content: "yes #{n}", is_correct: true},
          %{content: "no #{n}", is_correct: false}
        ]
      }
    end

    quiz_fixture(%{
      presentation_file: Claper.Presentations.get_presentation_file!(single.presentation_file_id),
      position: 1,
      enabled: true,
      show_results: true,
      quiz_questions: [question.(1), question.(2)]
    })

    {:ok, _} =
      Claper.Presentations.update_presentation_state(
        Claper.Presentations.get_presentation_file!(single.presentation_file_id, [
          :presentation_state
        ]).presentation_state,
        %{position: 1}
      )

    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")
    refute has_element?(manager, @next)

    render_hook(manager, "checked", %{"key" => "quiz_review", "value" => true})
    settle(manager, presenter)
    assert has_element?(manager, @next)
    assert has_element?(manager, @prev)

    render_hook(manager, "checked", %{"key" => "quiz_review", "value" => false})
    settle(manager, presenter)
    refute has_element?(manager, @next)
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
