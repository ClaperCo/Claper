defmodule ClaperWeb.UserConfirmationControllerTest do
  use ClaperWeb.ConnCase, async: true

  alias Claper.Accounts
  alias Claper.Repo
  import Claper.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "POST /users/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/confirm", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "confirm"
    end

    test "does not send confirmation token if User is confirmed", %{conn: conn, user: user} do
      Repo.update!(Accounts.User.confirm_changeset(user))

      conn =
        post(conn, ~p"/users/confirm", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      refute Repo.get_by(Accounts.UserToken, user_id: user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/confirm", %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert from(ut in Accounts.UserToken,
               where: ut.context == "confirm" and ut.sent_to == "unknown@example.com"
             )
             |> Repo.all() == []
    end
  end

  describe "POST /users/confirm/:token" do
    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/confirm/#{token}")
      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User confirmed successfully"
      assert Accounts.get_user!(user.id).confirmed_at
      refute get_session(conn, :user_token)

      assert from(ut in Accounts.UserToken,
               where: ut.context == "confirm" and ut.user_id == ^user.id
             )
             |> Repo.all() == []

      # When not logged in
      conn = get(conn, ~p"/users/confirm/#{token}")
      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "User confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_user(user)
        |> get(~p"/users/confirm/#{token}")

      assert redirected_to(conn) == "/events"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, ~p"/users/confirm/#{"oops"}")
      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "User confirmation link is invalid or it has expired"

      refute Accounts.get_user!(user.id).confirmed_at
    end
  end
end
