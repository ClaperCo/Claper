defmodule ClaperWeb.LtiControllerTest do
  use ClaperWeb.ConnCase, async: true

  describe "GET /.well-known/jwks.json" do
    test "returns the public key", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/jwks.json")
      response = json_response(conn, 200)
      assert response["keys"]
    end
  end

  describe "GET /lti/login" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, ~p"/users/log_in")
      response = html_response(conn, 200)
      assert response =~ "Your email address"
    end

    test "redirects if already logged in", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/users/log_in")
      assert redirected_to(conn) == "/events"
    end
  end

  describe "POST /lti/login" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log_out")
      assert redirected_to(conn) == "/"
      refute get_session(conn, :user_token)
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == "/"
      refute get_session(conn, :user_token)
    end
  end
end
