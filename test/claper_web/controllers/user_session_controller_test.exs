defmodule ClaperWeb.UserSessionControllerTest do
  use ClaperWeb.ConnCase, async: false

  import Claper.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "GET /users/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, ~p"/users/log_in")
      response = html_response(conn, 200)
      assert response =~ "Email address"
    end

    test "redirects if already logged in", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/users/log_in")
      assert redirected_to(conn) == "/events"
    end
  end

  describe "GET /users/log_in with DISABLE_PASSWORD_LOGIN" do
    setup do
      oidc = Application.get_env(:claper, :oidc)
      on_exit(fn -> Application.put_env(:claper, :oidc, oidc) end)
      :ok
    end

    test "hides the password form when disabled and OIDC is enabled", %{conn: conn} do
      Application.put_env(
        :claper,
        :oidc,
        Keyword.merge(Application.get_env(:claper, :oidc),
          enabled: true,
          client_id: "test-client",
          client_secret: "test-secret",
          disable_password_login: true
        )
      )

      conn = get(conn, ~p"/users/log_in")
      response = html_response(conn, 200)
      refute response =~ "type=\"password\""
      refute response =~ "href=\"/users/reset_password\""
      refute response =~ "href=\"/users/register\""
      assert response =~ "href=\"/users/oidc\""
    end

    test "shows the password form when password login is enabled", %{
      conn: conn
    } do
      Application.put_env(
        :claper,
        :oidc,
        Keyword.merge(Application.get_env(:claper, :oidc),
          enabled: false,
          client_id: nil,
          client_secret: nil,
          disable_password_login: false
        )
      )

      conn = get(conn, ~p"/users/log_in")
      response = html_response(conn, 200)
      assert response =~ "Email address"
    end
  end

  describe "POST /users/log_in with DISABLE_PASSWORD_LOGIN" do
    setup do
      oidc = Application.get_env(:claper, :oidc)
      on_exit(fn -> Application.put_env(:claper, :oidc, oidc) end)
      :ok
    end

    test "redirects to OIDC instead of checking the password", %{conn: conn, user: user} do
      Application.put_env(
        :claper,
        :oidc,
        Keyword.merge(Application.get_env(:claper, :oidc),
          enabled: true,
          client_id: "test-client",
          client_secret: "test-secret",
          disable_password_login: true
        )
      )

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/users/oidc"
      refute get_session(conn, :user_token)
    end
  end

  describe "DELETE /users/log_out" do
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
