defmodule Claper.Workers.QuizLti do
  alias Claper.Quizzes.Quiz
  use Oban.Worker, queue: :default

  alias Lti13.Tool.Services.{AGS, AccessToken}
  alias Lti13.Tool.Services.AGS.{Score, LineItem}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "create", "quiz_id" => quiz_id}}) do
    with quiz <- Claper.Quizzes.get_quiz!(quiz_id),
         presentation_file <-
           Claper.Presentations.get_presentation_file!(quiz.presentation_file_id,
             event: [lti_resource: [:registration]]
           ),
         %Lti13.Resources.Resource{} = lti_resource <- presentation_file.event.lti_resource,
         {:ok, token} <- Lti13.Tool.Services.AccessToken.fetch_access_token(lti_resource) do
      case AGS.create_line_item(
             lti_resource.line_items_url,
             lti_resource.resource_id,
             100,
             quiz.title,
             token
           ) do
        {:ok, line_item} ->
          quiz
          |> Quiz.update_line_item_changeset(%{lti_line_item_url: line_item.id})
          |> Claper.Repo.update()

        {:error, error} ->
          {:error, error}
      end
    end
  end

  def perform(%Oban.Job{args: %{"action" => "update", "quiz_id" => quiz_id}}) do
    with quiz <- Claper.Quizzes.get_quiz!(quiz_id),
         presentation_file <-
           Claper.Presentations.get_presentation_file!(quiz.presentation_file_id,
             event: [lti_resource: [:registration]]
           ),
         %Lti13.Resources.Resource{} = lti_resource <- presentation_file.event.lti_resource,
         {:ok, token} <- Lti13.Tool.Services.AccessToken.fetch_access_token(lti_resource) do
      AGS.update_line_item(
        %AGS.LineItem{
          id: quiz.lti_line_item_url,
          label: quiz.title,
          scoreMaximum: 100,
          resourceId: lti_resource.resource_id
        },
        %{label: quiz.title},
        token
      )
    end
  end

  def perform(%Oban.Job{
        args: %{
          "action" => "post_score",
          "quiz_id" => quiz_id,
          "user_id" => user_id,
          "score" => score,
          "timestamp" => timestamp
        }
      }) do
    with quiz <- Claper.Quizzes.get_quiz!(quiz_id, [:lti_resource]),
         user <- Claper.Accounts.get_user!(user_id) |> Claper.Repo.preload(:lti_user) do
      case AccessToken.fetch_access_token(quiz.lti_resource) do
        {:ok, access_token} ->
          line_item = %LineItem{
            id: quiz.lti_line_item_url,
            scoreMaximum: 100.0,
            label: quiz.title,
            resourceId: quiz.lti_resource.resource_id
          }

          post_score(line_item, user.lti_user, score, timestamp, access_token)

        {:error, msg} ->
          {:error, msg}
      end
    end
  end

  defp post_score(line_item, %Lti13.Users.User{sub: user_id}, score, timestamp, access_token) do
    AGS.post_score(
      %Score{
        scoreGiven: score,
        scoreMaximum: 100.0,
        activityProgress: "Completed",
        gradingProgress: "FullyGraded",
        userId: user_id,
        comment: "",
        timestamp: timestamp
      },
      line_item,
      access_token
    )
  end

  def edit(quiz_id) do
    new(%{
      "action" => "update",
      "quiz_id" => quiz_id
    })
  end

  def create(quiz_id) do
    new(%{
      "action" => "create",
      "quiz_id" => quiz_id
    })
  end

  def post_score(quiz_id, user_id, score, timestamp) do
    new(%{
      "action" => "post_score",
      "quiz_id" => quiz_id,
      "user_id" => user_id,
      "score" => score,
      "timestamp" => timestamp
    })
  end
end
