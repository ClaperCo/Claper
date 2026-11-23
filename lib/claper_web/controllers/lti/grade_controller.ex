defmodule ClaperWeb.Lti.GradeController do
  use ClaperWeb, :controller

  alias Lti13.Tool.Services.AGS
  alias Lti13.Tool.Services.AGS.Score

  def create(conn, _params) do
    resource_id = conn |> get_session(:resource_id) |> String.to_integer()
    user_id = conn |> get_session(:user_id)
    timestamp = get_timestamp()

    case fetch_access_token() do
      {:ok, access_token} ->
        handle_line_item(conn, resource_id, user_id, timestamp, access_token)

      {:error, msg} ->
        conn |> send_resp(500, msg)
    end
  end

  defp get_timestamp do
    {:ok, dt} = DateTime.now("Etc/UTC")
    DateTime.to_iso8601(dt)
  end

  defp fetch_access_token do
    Lti13.Tool.Services.AccessToken.fetch_access_token(
      %{
        auth_token_url: "http://localhost.charlesproxy.com/mod/lti/token.php",
        client_id: "NQQ8egz8Kj1s1qw",
        auth_server: "http://localhost.charlesproxy.com"
      },
      [
        "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
        "https://purl.imsglobal.org/spec/lti-ags/scope/score"
      ],
      "http://localhost:4000"
    )
  end

  defp handle_line_item(conn, resource_id, user_id, timestamp, access_token) do
    case AGS.fetch_or_create_line_item(
           "http://localhost.charlesproxy.com/mod/lti/services.php/2/lineitems?type_id=2",
           resource_id,
           fn -> 100.0 end,
           "test",
           access_token
         ) do
      {:ok, line_item} ->
        post_score(line_item, user_id, timestamp, access_token)
        conn |> send_resp(200, "")
    end
  end

  defp post_score(line_item, user_id, timestamp, access_token) do
    AGS.post_score(
      %Score{
        scoreGiven: 90.0,
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
end
