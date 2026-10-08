defmodule ClaperWeb.UserOidcAuthRouteTest do
  use ClaperWeb.ConnCase, async: true

  alias Claper.Accounts.Oidc

  @provider %{
    name: "Google",
    issuer: "https://issuer.invalid",
    client_id: "client-id",
    client_secret: "client-secret",
    redirect_uri: "http://localhost:4000/users/auth/google/callback"
  }

  test "the login page offers one button per enabled provider", %{conn: conn} do
    {:ok, _provider} = Oidc.create_provider(@provider)

    body =
      conn
      |> get("/users/log_in")
      |> response(200)

    assert body =~ ~s(href="/users/auth/google")
    assert body =~ "Log in with Google"
  end

  test "a disabled provider is not offered", %{conn: conn} do
    {:ok, _provider} = Oidc.create_provider(Map.put(@provider, :active, false))

    body =
      conn
      |> get("/users/log_in")
      |> response(200)

    refute body =~ ~s(href="/users/auth/google")
  end

  test "an unknown provider slug is refused before any redirect", %{conn: conn} do
    conn = get(conn, "/users/auth/nope")

    assert response(conn, 400) =~ "Authentication failed"
  end

  test "the legacy route refuses when no provider is configured", %{conn: conn} do
    conn = get(conn, "/users/oidc")

    assert response(conn, 400) =~ "no OIDC provider is configured"
  end
end
