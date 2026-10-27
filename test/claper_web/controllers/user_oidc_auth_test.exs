defmodule ClaperWeb.UserOidcAuthTest do
  use ClaperWeb.ConnCase

  import Claper.AccountsFixtures

  alias Claper.Accounts

  @pending_key "oidc_pending_confirmation"

  # config/runtime.exs replaces the test adapter with the one MAIL_TRANSPORT selects.
  setup do
    mailer_config = Application.get_env(:claper, Claper.Mailer)
    Application.put_env(:claper, Claper.Mailer, adapter: Swoosh.Adapters.Test)
    on_exit(fn -> Application.put_env(:claper, Claper.Mailer, mailer_config) end)

    user = user_fixture()

    attrs = %{
      sub: Ecto.UUID.generate(),
      issuer: "https://login.microsoftonline.com/tenant/v2.0",
      email: user.email,
      provider: "Entra ID",
      expires_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      id_token: "id-token",
      access_token: "access-token",
      refresh_token: ""
    }

    assert {:confirmation_sent, secret} =
             Accounts.authenticate_oidc_identity(attrs, fn token ->
               send(self(), {:oidc_confirmation_token, token})
               "https://claper.test/users/oidc/confirm/#{token}"
             end)

    assert_received {:oidc_confirmation_token, token}
    %{user: user, secret: secret, token: token}
  end

  test "a link opened without the initiating browser session never signs in", ctx do
    assert redirected_to(get(ctx.conn, ~p"/users/oidc/confirm")) == ~p"/users/log_in"

    assert html_response(get(ctx.conn, ~p"/users/oidc/confirm/#{ctx.token}"), 400) =~
             "different browser"

    conn = post(ctx.conn, ~p"/users/oidc/confirm/#{ctx.token}")

    assert html_response(conn, 400) =~ "different browser"
    refute get_session(conn, :user_token)
    assert Accounts.get_all_oidc_users_by_email(ctx.user.email) == []
  end

  test "the initiating browser confirms through a CSRF-protected form", ctx do
    conn = init_test_session(ctx.conn, %{@pending_key => ctx.secret})

    assert html_response(get(conn, ~p"/users/oidc/confirm"), 200) =~ "Check your email"

    page = get(conn, ~p"/users/oidc/confirm/#{ctx.token}")
    html = html_response(page, 200)
    assert Accounts.get_all_oidc_users_by_email(ctx.user.email) == []

    assert_error_sent 403, fn ->
      page |> recycle() |> enforce_csrf() |> post(~p"/users/oidc/confirm/#{ctx.token}")
    end

    confirmed =
      page
      |> recycle()
      |> enforce_csrf()
      |> post(~p"/users/oidc/confirm/#{ctx.token}", %{"_csrf_token" => hidden(html)})

    assert redirected_to(confirmed) == ~p"/events"
    assert session_user(confirmed).id == ctx.user.id
    assert [identity] = Accounts.get_all_oidc_users_by_email(ctx.user.email)
    assert identity.user_id == ctx.user.id
  end

  defp enforce_csrf(conn), do: Plug.Conn.put_private(conn, :plug_skip_csrf_protection, false)

  defp hidden(html) do
    [_, value] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, html)
    value
  end

  defp session_user(conn),
    do: Accounts.get_user_by_session_token(get_session(conn, :user_token))
end
