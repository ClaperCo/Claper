defmodule ClaperWeb.Plugs.CSRFProtectionTest do
  use ClaperWeb.ConnCase, async: true

  # Phoenix.ConnTest.build_conn/0 marks the connection so that Plug.CSRFProtection
  # skips the check, which is why the controller tests can post without a token.
  # Turning that flag off here is what makes the check run.
  test "renders the CSRF error page instead of raising", %{conn: conn} do
    conn =
      conn
      |> put_private(:plug_skip_csrf_protection, false)
      |> post(~p"/users/log_in", %{
        "user" => %{"email" => "nobody@example.com", "password" => "not-the-password"}
      })

    assert conn.halted
    assert html_response(conn, 403) =~ "CSRF Verification Failed"
  end

  test "lets the request through when the token matches the session", %{conn: conn} do
    conn = get(conn, ~p"/users/log_in")

    # The page carries a token masked for that session.
    [tag] = Regex.run(~r/<meta[^>]*name="csrf-token"[^>]*>/, conn.resp_body)
    [_, token] = Regex.run(~r/content="([^"]+)"/, tag)

    # post/3 recycles the connection, which puts the skip flag back, so recycle by
    # hand first. The session cookie from the GET is kept.
    conn =
      conn
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post(~p"/users/log_in", %{
        "_csrf_token" => token,
        "user" => %{"email" => "nobody@example.com", "password" => "not-the-password"}
      })

    # The check ran and accepted the token, so the request reached the controller.
    assert conn.private[:plug_skip_csrf_protection] == false
    assert html_response(conn, 200) =~ "Invalid email or password"
  end
end
