defmodule ClaperWeb.EventLive.InteractionComponentsTest do
  use ClaperWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Claper.Embeds.Embed
  alias Claper.Forms.Form
  alias Claper.Polls.{Poll, PollOpt}
  alias Claper.Quizzes.{Quiz, QuizQuestion, QuizQuestionOpt}
  alias ClaperWeb.EventLive.{EmbedComponent, FormComponent, PollComponent, QuizComponent}

  test "poll uses the feature preview card and selected option styling" do
    poll = %Poll{
      title: "Which topic should be next?",
      multiple: false,
      poll_opts: [
        %PollOpt{id: 1, content: "LiveView", percentage: 0.0, vote_count: 0}
      ]
    }

    document =
      PollComponent
      |> render_component(
        id: "poll-component",
        poll: poll,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{},
        selected_poll_opt: ["0"],
        current_poll_vote: [],
        show_results: false
      )
      |> Floki.parse_document!()

    assert_card_shell(document, "#extended-poll", "#poll-pane")
    assert Floki.find(document, "#collapsed-poll > button") != []
    option_classes = classes(document, "#poll-opt-0")
    vote_classes = classes(document, ~s(button[phx-click="vote"]))

    assert "bg-primary-900/40" in option_classes
    assert "py-2" in option_classes
    assert "shrink-0" in option_classes
    refute "overflow-y-auto" in classes(document, "#poll-options")
    refute "min-h-11" in option_classes
    assert Floki.attribute(document, "#poll-opt-0", "aria-pressed") == ["true"]
    assert "btn-gradient" in vote_classes
    assert "w-full" in vote_classes

    submitted_document =
      PollComponent
      |> render_component(
        id: "submitted-poll-component",
        poll: poll,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{},
        selected_poll_opt: [],
        current_poll_vote: [%{poll_opt_id: 1}],
        show_results: false
      )
      |> Floki.parse_document!()

    assert_submitted_button(submitted_document, "Voted")
  end

  test "word cloud reveals the cloud only when results are shared" do
    poll = %Poll{
      title: "One word for today?",
      type: :word_cloud,
      multiple: false,
      poll_opts: [
        %PollOpt{id: 1, content: "inspiring", percentage: 75.0, vote_count: 3},
        %PollOpt{id: 2, content: "dense", percentage: 25.0, vote_count: 1}
      ]
    }

    hidden =
      render_word_cloud(poll, "word-cloud-hidden", current_poll_vote: [%{poll_opt_id: 1}])

    assert hidden =~ "Thanks! Your word has been added to the cloud."
    refute hidden =~ "inspiring"
    refute hidden =~ "dense"

    shared =
      render_word_cloud(poll, "word-cloud-shared",
        current_poll_vote: [%{poll_opt_id: 1}],
        show_results: true
      )

    refute shared =~ "Thanks! Your word has been added to the cloud."
    assert shared =~ "inspiring"
    assert shared =~ "dense"
  end

  test "word cloud keeps the submit form until the attendee has submitted" do
    poll = %Poll{title: "One word for today?", type: :word_cloud, multiple: false, poll_opts: []}

    document =
      poll |> render_word_cloud("word-cloud-open") |> Floki.parse_document!()

    assert Floki.attribute(document, "form", "phx-submit") == ["submit-word"]

    submitted =
      poll
      |> render_word_cloud("word-cloud-done", current_poll_vote: [%{poll_opt_id: 1}])
      |> Floki.parse_document!()

    assert Floki.find(submitted, "form") == []
  end

  test "form uses the feature preview card and field styling" do
    form = %Form{
      title: "Tell us what you think",
      fields: [%{name: "Feedback", type: "text", required: false}]
    }

    document =
      FormComponent
      |> render_component(
        id: "form-component",
        form: form,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{},
        current_form_submit: nil
      )
      |> Floki.parse_document!()

    assert_card_shell(document, "#extended-form", "#form-pane")
    assert Floki.find(document, "#collapsed-form > button") != []
    submit_classes = classes(document, ~s(button[type="submit"]))

    assert "bg-gray-800" in classes(document, ~s(input[name="form_submit[Feedback]"]))
    assert "btn-gradient" in submit_classes
    assert "w-full" in submit_classes

    assert document
           |> Floki.find(~s(button[type="submit"]))
           |> Floki.text()
           |> String.trim() == "Send"

    submitted_document =
      FormComponent
      |> render_component(
        id: "submitted-form-component",
        form: form,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{},
        current_form_submit: %Claper.Forms.FormSubmit{response: %{"Feedback" => "Done"}}
      )
      |> Floki.parse_document!()

    assert_submitted_button(submitted_document, "Sent")

    assert Floki.attribute(
             submitted_document,
             ~s(input[name="form_submit[Feedback]"]),
             "readonly"
           ) ==
             ["readonly"]
  end

  test "quiz uses the feature preview card and selected answer styling" do
    option = %QuizQuestionOpt{id: 1, content: "10-20 minutes", is_correct: true}

    question = %QuizQuestion{
      id: 1,
      content: "How long can audiences stay focused?",
      quiz_question_opts: [option]
    }

    quiz = %Quiz{
      title: "Attention spans",
      allow_anonymous: true,
      show_results: false,
      quiz_questions: [question, %{question | id: 2}, %{question | id: 3}]
    }

    document =
      QuizComponent
      |> render_component(
        id: "quiz-component",
        quiz: quiz,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{},
        selected_quiz_question_opts: [option],
        current_quiz_question_idx: 2,
        current_quiz_responses: [],
        quiz_score: {0, 1}
      )
      |> Floki.parse_document!()

    assert_card_shell(document, "#extended-quiz", "#quiz-pane")
    assert Floki.find(document, "#collapsed-quiz > button") != []
    answer_classes = classes(document, ~s(button[phx-click="select-quiz-question-opt"]))
    submit_classes = classes(document, ~s(button[phx-click="submit-quiz"]))

    assert "bg-primary-900/40" in answer_classes
    assert "py-2" in answer_classes
    refute "min-h-11" in answer_classes

    assert Floki.attribute(
             document,
             ~s(button[phx-click="select-quiz-question-opt"]),
             "aria-pressed"
           ) ==
             ["true"]

    assert "btn-gradient" in submit_classes
    assert "flex-1" in submit_classes

    assert document
           |> Floki.find("#quiz-actions > button")
           |> Enum.map(&(&1 |> Floki.text() |> String.trim())) == ["Back", "Submit"]

    next_document =
      QuizComponent
      |> render_component(
        id: "next-quiz-component",
        quiz: quiz,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{},
        selected_quiz_question_opts: [option],
        current_quiz_question_idx: 1,
        current_quiz_responses: [],
        quiz_score: {0, 1}
      )
      |> Floki.parse_document!()

    assert next_document
           |> Floki.find("#quiz-actions > button")
           |> Enum.map(&(&1 |> Floki.text() |> String.trim())) == ["Back", "Next"]

    assert "flex-1" in classes(next_document, ~s(button[phx-click="next-question"]))

    sign_in_document =
      QuizComponent
      |> render_component(
        id: "sign-in-quiz-component",
        quiz: %{quiz | allow_anonymous: false},
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{},
        selected_quiz_question_opts: [option],
        current_quiz_question_idx: 2,
        current_quiz_responses: [],
        quiz_score: {0, 1}
      )
      |> Floki.parse_document!()

    assert "text-[10px]" in classes(sign_in_document, "#quiz-sign-in-prompt")

    assert sign_in_document
           |> Floki.find("#quiz-actions > div")
           |> List.first()
           |> elem(2)
           |> Enum.filter(&match?({_, _, _}, &1))
           |> Enum.map(&elem(&1, 0)) == ["a", "p"]

    submitted_quiz = %{quiz | show_results: true}

    submitted_document =
      QuizComponent
      |> render_component(
        id: "submitted-quiz-component",
        quiz: submitted_quiz,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{},
        selected_quiz_question_opts: [],
        current_quiz_question_idx: 3,
        current_quiz_responses: [%{quiz_question_opt_id: 1}],
        quiz_score: {1, 1}
      )
      |> Floki.parse_document!()

    assert Floki.find(submitted_document, "button[data-submitted]") == []

    assert submitted_document
           |> Floki.find(~s(button[phx-click="show-quiz-results"]))
           |> Floki.text()
           |> String.trim() == "Show results"

    assert "w-full" in classes(submitted_document, ~s(button[phx-click="show-quiz-results"]))

    review_document =
      QuizComponent
      |> render_component(
        id: "review-quiz-component",
        quiz: submitted_quiz,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{},
        selected_quiz_question_opts: [],
        current_quiz_question_idx: 1,
        current_quiz_responses: [%{quiz_question_opt_id: 1}],
        quiz_score: {1, 1}
      )
      |> Floki.parse_document!()

    assert review_document
           |> Floki.find("#quiz-review-actions > button")
           |> Enum.map(&(&1 |> Floki.text() |> String.trim())) == ["Back", "Next"]

    assert "flex-1" in classes(
             review_document,
             ~s(#quiz-review-actions button[phx-click="next-question"])
           )
  end

  test "web content uses the feature preview card and fills a responsive frame" do
    embed = %Embed{
      title: "Watch the demo",
      provider: "youtube",
      content: "https://youtu.be/video-id"
    }

    document =
      EmbedComponent
      |> render_component(
        id: "embed-component",
        embed: embed,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{}
      )
      |> Floki.parse_document!()

    assert_card_shell(document, "#extended-embed", "#embed-pane")
    assert Floki.find(document, "#collapsed-embed > button") != []
    assert "aspect-video" in classes(document, "#extended-embed > div:last-child")
    assert "h-full" in classes(document, "iframe")
    assert "w-full" in classes(document, "iframe")
    assert Floki.attribute(document, "iframe", "title") == ["Watch the demo"]

    focus_document =
      EmbedComponent
      |> render_component(id: "focus-embed-component", embed: embed, focus_mode: true)
      |> Floki.parse_document!()

    assert Floki.find(focus_document, "#collapsed-embed") == []
    assert Floki.find(focus_document, "#embed-pane") == []
    assert "shadow-none" in classes(focus_document, "#extended-embed")
  end

  test "custom web content is not cropped into a video aspect ratio" do
    embed = %Embed{
      title: "Interactive exercise",
      provider: "custom",
      content: ~s(<iframe height="450" src="https://example.com"></iframe>)
    }

    document =
      EmbedComponent
      |> render_component(
        id: "custom-embed-component",
        embed: embed,
        current_user: nil,
        attendee_identifier: "attendee",
        event: %{}
      )
      |> Floki.parse_document!()

    frame_classes = classes(document, "#extended-embed > div:last-child")

    assert "overflow-x-auto" in frame_classes
    refute "aspect-video" in frame_classes
    refute "overflow-hidden" in frame_classes
  end

  defp render_word_cloud(poll, id, overrides \\ []) do
    render_component(
      PollComponent,
      Keyword.merge(
        [
          id: id,
          poll: poll,
          current_user: nil,
          attendee_identifier: "attendee",
          event: %{},
          selected_poll_opt: [],
          current_poll_vote: [],
          show_results: false
        ],
        overrides
      )
    )
  end

  defp assert_card_shell(document, card_selector, close_selector) do
    assert "bg-gray-900" in classes(document, card_selector)
    assert "rounded-2xl" in classes(document, card_selector)
    assert "shadow-2xl" in classes(document, card_selector)
    assert Floki.attribute(document, close_selector, "aria-label") == ["Close"]
  end

  defp assert_submitted_button(document, text) do
    assert "w-full" in classes(document, "button[data-submitted]")
    assert Floki.attribute(document, "button[data-submitted]", "disabled") == ["disabled"]
    assert Floki.find(document, "button[data-submitted] svg") != []

    assert document
           |> Floki.find("button[data-submitted]")
           |> Floki.text()
           |> String.trim() == text
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end
end
