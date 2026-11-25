defmodule ClaperWeb.EventLive.ManageableQuizComponentTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, QuizzesFixtures}

  alias ClaperWeb.EventLive.ManageableQuizComponent

  setup [:register_and_log_in_user]

  setup %{user: user} do
    presentation_file = presentation_file_fixture(%{user: user, length: 2}, [:event])
    quiz = quiz_fixture(%{presentation_file: presentation_file, position: 0})

    quiz =
      Claper.Quizzes.get_quiz!(quiz.id, [:quiz_questions, quiz_questions: :quiz_question_opts])

    %{quiz: %{quiz | show_results: true}}
  end

  defp render_quiz(quiz, idx, extra \\ []) do
    render_component(
      ManageableQuizComponent,
      Keyword.merge(
        [id: "#{quiz.id}-quiz", quiz: quiz, iframe: false, current_question_idx: idx],
        extra
      )
    )
  end

  defp option_row(html, content) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find("div.rounded-xl")
    |> Enum.find(fn row -> Floki.text(row) =~ content end)
  end

  test "a reviewed question shows how the answers were distributed", %{quiz: quiz} do
    html = render_quiz(quiz, 0)

    for content <- ["option 1", "option 2"] do
      row = option_row(html, content)
      assert row, "no row for #{content}"
      # Like a poll: a bar sized by the percentage, followed by "<percent>% (<count>)".
      assert Floki.attribute(row, "div[style]", "style") != []
      assert Floki.text(row) =~ "%"
    end
  end

  test "the correct answer is highlighted in green, the others are not", %{quiz: quiz} do
    html = render_quiz(quiz, 0)

    correct = option_row(html, "option 1")
    wrong = option_row(html, "option 2")

    assert "bg-green-900" in class_list(correct)
    refute "bg-green-900" in class_list(wrong)
    assert "bg-green-500" in (correct |> Floki.find("div[style]") |> class_list())
    refute "bg-green-500" in (wrong |> Floki.find("div[style]") |> class_list())
  end

  test "the summary shows the average score as a percentage", %{quiz: quiz} do
    html = render_quiz(quiz, -1)

    assert html =~ "Average score"
    # Nobody answered yet: 0%, not "0/1".
    assert html =~ "0%"
    refute html =~ "0/1"
    refute option_row(html, "option 1")
  end

  test "outside the left column it is an overlay over the slide", %{quiz: quiz} do
    overlay = render_quiz(quiz, 0, beside: false)
    beside = render_quiz(quiz, 0, beside: true)

    assert overlay =~ "bg-black/90"
    refute beside =~ "bg-black/90"
  end

  defp class_list(nodes) do
    nodes
    |> List.wrap()
    |> Floki.attribute("class")
    |> Enum.flat_map(&String.split/1)
  end
end
