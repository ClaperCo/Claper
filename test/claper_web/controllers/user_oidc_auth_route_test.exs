defmodule ClaperWeb.UserOidcAuthRouteTest do
  # async: false because the auto redirect test rewrites the global :oidc
  # configuration, which concurrent cases must not observe.
  use ClaperWeb.ConnCase, async: false

  alias Claper.Accounts.Oidc

  @provider %{
    name: "Google",
    issuer: "https://issuer.invalid",
    client_id: "client-id",
    client_secret: "client-secret",
    redirect_uri: "http://localhost:4000/users/auth/google/callback"
  }

  describe "the login page" do
    test "offers one button per enabled provider", %{conn: conn} do
      {:ok, _provider} = Oidc.create_provider(@provider)

      body =
        conn
        |> get("/users/log_in")
        |> response(200)

      assert body =~ ~s(href="/users/auth/google")
      assert body =~ "Log in with Google"
    end

    test "does not offer a disabled provider", %{conn: conn} do
      {:ok, _provider} = Oidc.create_provider(Map.put(@provider, :active, false))

      body =
        conn
        |> get("/users/log_in")
        |> response(200)

      refute body =~ ~s(href="/users/auth/google")
    end

    test "orders the buttons by position", %{conn: conn} do
      {:ok, _} =
        Oidc.create_provider(
          Map.merge(@provider, %{name: "Second", issuer: "https://second.invalid", position: 2})
        )

      {:ok, _} =
        Oidc.create_provider(
          Map.merge(@provider, %{name: "First", issuer: "https://first.invalid", position: 1})
        )

      body =
        conn
        |> get("/users/log_in")
        |> response(200)

      assert {first, _} = :binary.match(body, "Log in with First")
      assert {second, _} = :binary.match(body, "Log in with Second")
      assert first < second
    end

    test "auto redirects to the first provider when asked", %{conn: conn} do
      original = Application.get_env(:claper, :oidc)
      on_exit(fn -> Application.put_env(:claper, :oidc, original) end)
      Application.put_env(:claper, :oidc, Keyword.put(original, :auto_redirect_login, true))

      {:ok, provider} = Oidc.create_provider(@provider)

      conn = get(conn, "/users/log_in")

      assert redirected_to(conn) == "/users/auth/#{provider.slug}"
    end
  end

  describe "the login route" do
    test "an unknown provider slug is refused before any redirect", %{conn: conn} do
      conn = get(conn, "/users/auth/nope")

      assert response(conn, 400) =~ "unknown or disabled provider"
      assert Plug.Conn.get_resp_header(conn, "location") == []
    end

    test "the legacy route refuses when no provider is configured", %{conn: conn} do
      conn = get(conn, "/users/oidc")

      assert response(conn, 400) =~ "no OIDC provider is configured"
    end
  end

  describe "the callback" do
    test "is refused when the authorization was started for another provider", %{conn: conn} do
      {:ok, _provider} = Oidc.create_provider(@provider)

      conn =
        conn
        |> Plug.Test.init_test_session(%{oidc_provider_slug: "entra", oidc_state: "state"})

      conn = get(conn, "/users/auth/google/callback?code=code&state=state")

      assert response(conn, 401) =~ "started for provider"
    end

    test "is refused when the state does not match", %{conn: conn} do
      {:ok, _provider} = Oidc.create_provider(@provider)

      conn =
        conn
        |> Plug.Test.init_test_session(%{oidc_provider_slug: "google", oidc_state: "expected"})

      conn = get(conn, "/users/auth/google/callback?code=code&state=other")

      assert response(conn, 401) =~ "state mismatch"
    end

    test "is refused when the state is missing", %{conn: conn} do
      conn = get(conn, "/users/auth/google/callback?code=code")

      assert response(conn, 401) =~ "missing state parameter"
    end

    test "surfaces the error the provider returned", %{conn: conn} do
      conn = get(conn, "/users/auth/google/callback?error=access_denied")

      assert response(conn, 401) =~ "access_denied"
    end
  end
end
