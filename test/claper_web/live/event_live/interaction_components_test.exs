defmodule ClaperWeb.EventLive.InteractionComponentsTest do
  use ClaperWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Claper.Embeds.Embed
  alias Claper.Forms.Form
  alias Claper.Polls.{Poll, PollOpt}
  alias Claper.Quizzes.{Quiz, QuizQuestion, QuizQuestionOpt}
  alias Claper.Scales.{Scale, ScaleResponse}
  alias Claper.WordClouds.{Entry, WordCloud}

  alias ClaperWeb.EventLive.{
    EmbedComponent,
    EmbedIframeComponent,
    FormComponent,
    PollComponent,
    QuizComponent,
    ScaleComponent,
    WordCloudComponent
  }

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
      content: "https://youtu.be/dQw4w9WgXcQ"
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

  test "custom iframes render escaped allowlisted attributes instead of supplied HTML" do
    document =
      EmbedIframeComponent
      |> render_component(
        id: "safe-custom-iframe",
        provider: "custom",
        title: "Interactive exercise",
        content: """
        <script id="security-probe">alert(1)</script>
        <iframe src='https://example.com/embed?a=1&amp;b=2' width='640' height='450'
          title='&quot; onload=&quot;alert(1)' onload='alert(1)'
          srcdoc='<script>alert(1)</script>' allowfullscreen sandbox='allow-scripts'>
          <script>alert(1)</script>
        </iframe>
        """
      )
      |> Floki.parse_fragment!()

    assert [_] = Floki.find(document, "iframe")
    assert Floki.attribute(document, "iframe", "src") == ["https://example.com/embed?a=1&b=2"]
    assert Floki.attribute(document, "iframe", "title") == [~s|" onload="alert(1)|]
    assert Floki.attribute(document, "iframe", "width") == ["640"]
    assert Floki.attribute(document, "iframe", "height") == ["450"]
    assert Floki.attribute(document, "iframe", "sandbox") == ["allow-scripts"]
    assert Floki.attribute(document, "iframe", "allowfullscreen") != []
    assert Floki.attribute(document, "iframe", "onload") == []
    assert Floki.attribute(document, "iframe", "srcdoc") == []
    assert Floki.find(document, "script") == []
  end

  test "historical custom iframe payloads cannot bypass URL validation when rendered" do
    for content <- [
          nil,
          "",
          "<iframe></iframe>",
          "<iframe src='https://'></iframe>",
          ~s|<iframe src="java&#x09;script:parent.document.body.dataset.securityProbe=1"></iframe>|,
          "<iframe src='java\tscript:alert(1)'></iframe>",
          ~s|<iframe src='javascript:alert(1)'></iframe>|,
          ~s|<iframe src="data:text/html,<script>alert(1)</script>"></iframe>|,
          ~s|<iframe src="https://example.com" src="javascript:alert(1)"></iframe>|,
          ~s|<iframe srcdoc="<script>alert(1)</script>" onload="alert(1)"></iframe>|
        ] do
      document =
        EmbedIframeComponent
        |> render_component(
          id: "unsafe-custom-iframe",
          provider: "custom",
          title: "Legacy content",
          content: content
        )
        |> Floki.parse_fragment!()

      assert Floki.find(document, "iframe") == []
      assert Floki.find(document, "script") == []
    end
  end

  test "provider frames only load the provider's own domain" do
    render_src = fn provider, content ->
      EmbedIframeComponent
      |> render_component(
        id: "provider-frame",
        provider: provider,
        title: "Slides",
        content: content
      )
      |> Floki.parse_fragment!()
      |> Floki.attribute("iframe", "src")
    end

    # Stored before validation existed: never framed.
    for {provider, content} <- [
          {"canva", "https://evil.example/?canva.com"},
          {"canva", "https://canva.com.evil.example/design/abc/view"},
          {"googleslides", "https://evil.example/?google.com"},
          {"googleslides", "https://sites.google.com/view/phishing"},
          {"youtube", "https://evil.example/?youtu.be/../../redirect?q=https://evil.example"},
          {"youtube", "https://youtu.be/../../redirect?q=https://evil.example"},
          {"vimeo", "https://evil.example/?vimeo.com/../../evil"},
          {"youtube", nil},
          {"canva", nil},
          {"googleslides", ""}
        ] do
      assert render_src.(provider, content) == []
    end

    assert render_src.("canva", "https://www.canva.com/design/DAF1234/view") ==
             ["https://www.canva.com/design/DAF1234/view?embed"]

    assert render_src.("canva", "http://canva.com/design/DAF1234/view?utm_content=x") ==
             ["https://canva.com/design/DAF1234/view?utm_content=x&embed"]

    assert render_src.(
             "googleslides",
             "https://docs.google.com/presentation/d/e/2PACX-1vQ/pub?start=false&loop=false"
           ) ==
             ["https://docs.google.com/presentation/d/e/2PACX-1vQ/embed?start=false&loop=false"]

    for content <- [
          "https://youtu.be/dQw4w9WgXcQ?si=g1A6ZegIXzcrisSw",
          "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42",
          "https://m.youtube.com/shorts/dQw4w9WgXcQ"
        ] do
      assert render_src.("youtube", content) == ["https://www.youtube.com/embed/dQw4w9WgXcQ"]
    end

    assert render_src.("vimeo", "https://vimeo.com/123456789") ==
             ["https://player.vimeo.com/video/123456789"]

    assert render_src.("vimeo", "https://vimeo.com/123456789/abcdef1234") ==
             ["https://player.vimeo.com/video/123456789?h=abcdef1234"]
  end

  test "word cloud offers an input until the attendee has sent all their words" do
    word_cloud = %WordCloud{id: 7, title: "One word", max_entries: 2, show_results: true}
    entry = %Entry{content: "Elixir", normalized_content: "elixir"}
    words = [%{key: "elixir", text: "Elixir", count: 1}]

    document =
      WordCloudComponent
      |> render_component(
        id: "word-cloud-component",
        word_cloud: word_cloud,
        entries: [],
        words: []
      )
      |> Floki.parse_document!()

    assert "bg-gray-900" in classes(document, "#extended-word-cloud")
    assert Floki.attribute(document, ~s(input[name="word"]), "maxlength") == ["60"]
    assert "btn-gradient" in classes(document, ~s(button[type="submit"]))
    assert Floki.find(document, "[data-submitted]") == []

    one_sent_document =
      WordCloudComponent
      |> render_component(
        id: "one-sent-word-cloud-component",
        word_cloud: word_cloud,
        entries: [entry],
        words: words
      )
      |> Floki.parse_document!()

    assert Floki.find(one_sent_document, ~s(input[name="word"])) != []

    assert one_sent_document |> Floki.raw_html() |> word_cloud_words() == [
             %{"id" => "elixir", "name" => "Elixir", "count" => 1}
           ]

    assert Floki.attribute(
             one_sent_document,
             "#one-sent-word-cloud-component-cloud",
             "phx-update"
           ) ==
             ["ignore"]

    done_document =
      WordCloudComponent
      |> render_component(
        id: "done-word-cloud-component",
        word_cloud: %{word_cloud | max_entries: 1},
        entries: [entry],
        words: words
      )
      |> Floki.parse_document!()

    assert Floki.find(done_document, ~s(input[name="word"])) == []
    assert Floki.find(done_document, "[data-submitted]") != []
  end

  test "word cloud renders no cloud and no hidden own word when they must stay out of view" do
    word_cloud = %WordCloud{
      id: 7,
      title: "One word",
      max_entries: 2,
      show_results: false,
      hidden_words: ["rude"]
    }

    html =
      render_component(WordCloudComponent,
        id: "hidden-word-cloud-component",
        word_cloud: word_cloud,
        entries: [
          %Entry{content: "Rude", normalized_content: "rude"},
          %Entry{content: "Kind", normalized_content: "kind"}
        ],
        words: [%{key: "kind", text: "Kind", count: 1}]
      )

    assert html =~ "Kind"
    refute html =~ "Rude"
    refute html =~ "hidden-word-cloud-component-cloud"
  end

  test "slider offers the range until the attendee has answered" do
    scale = %Scale{id: 7, title: "Confidence", min_value: 0, max_value: 20, step: 5}

    document =
      ScaleComponent
      |> render_component(
        id: "scale-component",
        scale: scale,
        selected: 10,
        response: nil,
        results: nil
      )
      |> Floki.parse_document!()

    assert "bg-gray-900" in classes(document, "#extended-scale")

    for {attribute, value} <- [
          {"min", "0"},
          {"max", "20"},
          {"step", "5"},
          {"value", "10"},
          {"name", "value"}
        ] do
      assert Floki.attribute(document, ~s(input[type="range"]), attribute) == [value]
    end

    assert Floki.find(document, "[data-answered]") == []

    results = %{
      count: 2,
      average: 12.5,
      median: 12.5,
      distribution: for(value <- [0, 5, 10, 15, 20], do: %{value: value, count: 0, weight: 0.0})
    }

    answered =
      ScaleComponent
      |> render_component(
        id: "answered-scale-component",
        scale: scale,
        selected: 10,
        response: %ScaleResponse{value: 15},
        results: results
      )
      |> Floki.parse_document!()

    assert Floki.find(answered, ~s(input[type="range"])) == []
    assert answered |> Floki.find("[data-answered]") |> Floki.text() =~ "15"
    assert answered |> Floki.find("#answered-scale-component-results") |> Floki.text() =~ "12.5"
  end

  test "slider renders no results when they must stay out of view" do
    html =
      render_component(ScaleComponent,
        id: "hidden-scale-component",
        scale: %Scale{id: 7, title: "Confidence", min_value: 1, max_value: 5, step: 1},
        selected: 3,
        response: %ScaleResponse{value: 4},
        results: nil
      )

    assert html =~ "Your answer"
    refute html =~ "hidden-scale-component-results"
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
