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
end
