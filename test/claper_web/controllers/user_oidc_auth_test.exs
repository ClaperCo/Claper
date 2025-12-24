defmodule ClaperWeb.UserOidcAuthTest do
  use ClaperWeb.ConnCase, async: true

  describe "new/2" do
    test "redirects to OIDC provider with state and nonce in session", %{conn: conn} do
      conn = get(conn, ~p"/users/oidc")
      
      assert redirected_to(conn) =~ "/authorization" # Assuming redirection URL contains /authorization or similar, checking generated URL structure might be hard without knowing provider config fully.
      # Actually, since we can't easily check the exact URL without mocking provider config, we can check the session.

      assert get_session(conn, :oidc_state)
      assert get_session(conn, :oidc_nonce)
      assert get_session(conn, :pkce_verifier)
      
      state = get_session(conn, :oidc_state)
      nonce = get_session(conn, :oidc_nonce)
      
      # Check lengths (base64 encoded 16 bytes is approx 22 chars, 32 bytes approx 43 chars)
      assert String.length(state) >= 20
      assert String.length(nonce) >= 40
    end
  end

  describe "callback/2" do
    test "fails when state is missing in params", %{conn: conn} do
      conn = 
        conn
        |> put_session(:oidc_state, "valid_state")
        |> get(~p"/users/oidc/callback", %{code: "some_code"})

      assert html_response(conn, 401) =~ "Authentication failed: invalid or missing state parameter"
      refute get_session(conn, :oidc_state)
    end

    test "fails when state is missing in session", %{conn: conn} do
      conn = 
        conn
        |> get(~p"/users/oidc/callback", %{code: "some_code", state: "some_state"})

      assert html_response(conn, 401) =~ "Authentication failed: invalid or missing state parameter"
    end

    test "fails when state mismatch", %{conn: conn} do
      conn = 
        conn
        |> put_session(:oidc_state, "valid_state")
        |> get(~p"/users/oidc/callback", %{code: "some_code", state: "invalid_state"})

      assert html_response(conn, 401) =~ "Authentication failed: invalid or missing state parameter"
      refute get_session(conn, :oidc_state)
    end

    test "fails when error param is present", %{conn: conn} do
      conn = get(conn, ~p"/users/oidc/callback", %{error: "access_denied"})
      
      assert html_response(conn, 401) =~ "Authentication failed: access_denied"
      refute get_session(conn, :oidc_state)
    end
  end
end
