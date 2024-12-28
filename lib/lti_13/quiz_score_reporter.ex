defmodule Lti13.QuizScoreReporter do
  alias Claper.Quizzes

  def report_quiz_score(%Quizzes.Quiz{} = quiz, user_id) do
    quiz =
      quiz
      |> Claper.Repo.preload(lti_resource: [:registration])

    if quiz.lti_resource do
      # Calculate score as percentage of correct answers
      score = calculate_score(quiz, user_id)
      timestamp = get_timestamp()

      Claper.Workers.QuizLti.post_score(quiz.id, user_id, score, timestamp) |> Oban.insert()
    else
      # No LTI resource
      {:ok, quiz}
    end
  end

  defp calculate_score(quiz, user_id) do
    {correct_answers, total_questions} = Quizzes.calculate_user_score(user_id, quiz.id)

    correct_answers / total_questions * 100
  end

  defp get_timestamp do
    {:ok, dt} = DateTime.now("Etc/UTC")
    DateTime.to_iso8601(dt)
  end
end
