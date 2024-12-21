defmodule Claper.QuizzesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Quizzes` context.
  """

  import Claper.PresentationsFixtures

  def quiz_fixture(attrs \\ %{}) do
    presentation_file = attrs[:presentation_file] || presentation_file_fixture()

    attrs =
      attrs
      |> Enum.into(%{
        title: "some quiz title",
        position: 42,
        enabled: false,
        show_results: false,
        presentation_file_id: presentation_file.id,
        quiz_questions: [
          %{
            content: "some question content",
            type: "qcm",
            quiz_question_opts: [
              %{
                content: "option 1",
                is_correct: true
              },
              %{
                content: "option 2",
                is_correct: false
              }
            ]
          }
        ],
        lti_resource_id: nil,
        lti_line_item_url: nil
      })

    case Claper.Quizzes.create_quiz(attrs) do
      {:ok, quiz} ->
        quiz

      {:error, changeset} ->
        raise "Failed to create quiz: #{inspect(changeset.errors)}"
    end
  end
end
