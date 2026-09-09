defmodule ClaperWeb.UserRegistrationControllerTest do
  use ClaperWeb.ConnCase, async: false

  import Claper.AccountsFixtures

  alias Claper.Accounts

  setup do
    enable_account_creation = Application.get_env(:claper, :enable_account_creation)
    email_confirmation = Application.get_env(:claper, :email_confirmation)
    terms_url = Application.get_env(:claper, :terms_url)
    privacy_url = Application.get_env(:claper, :privacy_url)
    oidc = Application.get_env(:claper, :oidc)

    Application.put_env(:claper, :oidc, Keyword.put(oidc, :disable_password_login, false))

    on_exit(fn ->
      Application.put_env(:claper, :enable_account_creation, enable_account_creation)
      Application.put_env(:claper, :email_confirmation, email_confirmation)
      Application.put_env(:claper, :terms_url, terms_url)
      Application.put_env(:claper, :privacy_url, privacy_url)
      Application.put_env(:claper, :oidc, oidc)
    end)

    :ok
  end

  describe "GET /users/register" do
    test "renders the registration page when account creation is enabled", %{conn: conn} do
      Application.put_env(:claper, :enable_account_creation, true)

      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)

      assert response =~ "action=\"/users/register\""
      assert response =~ "name=\"user[first_name]\""
      assert response =~ "name=\"user[last_name]\""
      assert response =~ "name=\"user[email]\""
      assert response =~ "name=\"user[password]\""
      assert response =~ "name=\"user[password_confirmation]\""
      assert response =~ "/users/log_in"
    end

    test "redirects to the home page when account creation is disabled", %{conn: conn} do
      Application.put_env(:claper, :enable_account_creation, false)

      conn = get(conn, ~p"/users/register")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Account creation is disabled"
    end

    test "redirects authenticated users away from registration", %{conn: conn} do
      Application.put_env(:claper, :enable_account_creation, true)
      user = confirmed_user_fixture()

      conn = conn |> log_in_user(user) |> get(~p"/users/register")

      assert redirected_to(conn) == "/events"
    end

    test "shows the legal notice when both TERMS_URL and PRIVACY_URL are configured", %{
      conn: conn
    } do
      Application.put_env(:claper, :enable_account_creation, true)
      Application.put_env(:claper, :terms_url, "https://example.com/terms")
      Application.put_env(:claper, :privacy_url, "https://example.com/privacy")

      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)

      assert response =~ "By creating an account"
      assert response =~ "https://example.com/terms"
      assert response =~ "https://example.com/privacy"
    end

    test "hides the legal notice when only TERMS_URL is configured", %{conn: conn} do
      Application.put_env(:claper, :enable_account_creation, true)
      Application.put_env(:claper, :terms_url, "https://example.com/terms")
      Application.put_env(:claper, :privacy_url, nil)

      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)

      refute response =~ "By creating an account"
      refute response =~ "https://example.com/terms"
    end

    test "hides the legal notice when only PRIVACY_URL is configured", %{conn: conn} do
      Application.put_env(:claper, :enable_account_creation, true)
      Application.put_env(:claper, :terms_url, nil)
      Application.put_env(:claper, :privacy_url, "https://example.com/privacy")

      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)

      refute response =~ "By creating an account"
      refute response =~ "https://example.com/privacy"
    end

    test "hides the legal notice when neither URL is configured", %{conn: conn} do
      Application.put_env(:claper, :enable_account_creation, true)
      Application.put_env(:claper, :terms_url, nil)
      Application.put_env(:claper, :privacy_url, nil)

      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)

      refute response =~ "By creating an account"
    end
  end

  describe "POST /users/register" do
    for {account_creation, password_login_disabled} <- [{false, false}, {true, true}] do
      test "rejects registration with account creation #{account_creation} and password login disabled #{password_login_disabled}",
           %{conn: conn} do
        Application.put_env(:claper, :enable_account_creation, unquote(account_creation))
        Application.put_env(:claper, :email_confirmation, false)

        Application.put_env(
          :claper,
          :oidc,
          Keyword.merge(Application.get_env(:claper, :oidc),
            enabled: true,
            disable_password_login: unquote(password_login_disabled)
          )
        )

        get_conn = get(conn, ~p"/users/register")
        assert redirected_to(get_conn) == "/"
        assert Phoenix.Flash.get(get_conn.assigns.flash, :error) =~ "Account creation is disabled"

        email = unique_user_email()

        conn =
          post(conn, ~p"/users/register", %{
            "user" => %{
              "first_name" => "Jane",
              "last_name" => "Doe",
              "email" => email,
              "password" => valid_user_password(),
              "password_confirmation" => valid_user_password()
            }
          })

        assert redirected_to(conn) == "/"
        assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Account creation is disabled"
        refute get_session(conn, :user_token)
        refute Accounts.get_user_by_email(email)
      end
    end

    test "re-renders the page with errors for invalid data", %{conn: conn} do
      Application.put_env(:claper, :enable_account_creation, true)

      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{
            "email" => "with spaces",
            "password" => "123456",
            "password_confirmation" => "654321"
          }
        })

      response = html_response(conn, 200)

      assert response =~ "Oops, check that all fields are filled in correctly."
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "does not match confirmation"
    end

    test "creates and logs in the user when email confirmation is disabled", %{conn: conn} do
      Application.put_env(:claper, :enable_account_creation, true)
      Application.put_env(:claper, :email_confirmation, false)

      email = unique_user_email()

      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{
            "first_name" => "Jane",
            "last_name" => "Doe",
            "email" => email,
            "password" => valid_user_password(),
            "password_confirmation" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/events"
      assert get_session(conn, :user_token)
      user = Accounts.get_user_by_email(email)
      assert user.first_name == "Jane"
      assert user.last_name == "Doe"
    end

    test "creates the user and redirects to confirmation when email confirmation is enabled", %{
      conn: conn
    } do
      Application.put_env(:claper, :enable_account_creation, true)
      Application.put_env(:claper, :email_confirmation, true)

      email = unique_user_email()

      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{
            "first_name" => "Jane",
            "last_name" => "Doe",
            "email" => email,
            "password" => valid_user_password(),
            "password_confirmation" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/users/register/confirm"
      refute get_session(conn, :user_token)

      user = Accounts.get_user_by_email(email)
      assert user
      assert user.first_name == "Jane"
      assert user.last_name == "Doe"
      refute user.confirmed_at
    end
  end
end
