defmodule Claper.InteractionsTest do
  use Claper.DataCase

  alias Claper.Interactions
  alias Claper.{Forms, Polls, Quizzes}

  import Claper.{
    EmbedsFixtures,
    FormsFixtures,
    PollsFixtures,
    PresentationsFixtures,
    QuizzesFixtures
  }

  describe "duplicate_interaction/1" do
    test "duplicates a poll without copying results" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          enabled: true,
          poll_opts: [
            %{content: "Yes", vote_count: 4},
            %{content: "No", vote_count: 2}
          ]
        })

      assert {:ok, duplicate} = Interactions.duplicate_interaction(poll)

      duplicate = Polls.get_poll!(duplicate.id)
      [first_opt, second_opt] = duplicate.poll_opts

      assert duplicate.id != poll.id
      assert duplicate.title == "#{poll.title} (Copy)"
      assert duplicate.enabled == false
      assert duplicate.position == poll.position
      assert duplicate.presentation_file_id == poll.presentation_file_id
      assert first_opt.content == "Yes"
      assert first_opt.vote_count == 0
      assert second_opt.content == "No"
      assert second_opt.vote_count == 0
    end

    test "duplicates a form without copying submissions" do
      presentation_file = presentation_file_fixture()
      form = form_fixture(%{presentation_file_id: presentation_file.id, enabled: true})

      assert {:ok, duplicate} = Interactions.duplicate_interaction(form)

      duplicate = Forms.get_form!(duplicate.id, [:form_submits])

      assert duplicate.id != form.id
      assert duplicate.title == "#{form.title} (Copy)"
      assert duplicate.enabled == false
      assert duplicate.position == form.position
      assert duplicate.presentation_file_id == form.presentation_file_id
      assert duplicate.fields == form.fields
      assert duplicate.form_submits == []
    end

    test "duplicates an embed in a disabled state" do
      presentation_file = presentation_file_fixture()
      embed = embed_fixture(%{presentation_file_id: presentation_file.id, enabled: true})

      assert {:ok, duplicate} = Interactions.duplicate_interaction(embed)

      assert duplicate.id != embed.id
      assert duplicate.title == "#{embed.title} (Copy)"
      assert duplicate.enabled == false
      assert duplicate.position == embed.position
      assert duplicate.presentation_file_id == embed.presentation_file_id
      assert duplicate.content == embed.content
      assert duplicate.provider == embed.provider
      assert duplicate.attendee_visibility == embed.attendee_visibility
    end

    test "duplicates a quiz without copying response counts" do
      presentation_file = presentation_file_fixture()

      quiz =
        quiz_fixture(%{
          presentation_file: presentation_file,
          enabled: true,
          quiz_questions: [
            %{
              content: "Question 1",
              type: "qcm",
              quiz_question_opts: [
                %{content: "Option 1", is_correct: true, response_count: 5},
                %{content: "Option 2", is_correct: false, response_count: 3}
              ]
            }
          ]
        })

      assert {:ok, duplicate} = Interactions.duplicate_interaction(quiz)

      duplicate =
        Quizzes.get_quiz!(duplicate.id, [:quiz_questions, quiz_questions: :quiz_question_opts])

      [question] = duplicate.quiz_questions
      [first_opt, second_opt] = question.quiz_question_opts

      assert duplicate.id != quiz.id
      assert duplicate.title == "#{quiz.title} (Copy)"
      assert duplicate.enabled == false
      assert duplicate.position == quiz.position
      assert duplicate.presentation_file_id == quiz.presentation_file_id
      assert question.content == "Question 1"
      assert first_opt.content == "Option 1"
      assert first_opt.response_count == 0
      assert second_opt.content == "Option 2"
      assert second_opt.response_count == 0
    end
  end
end
