defmodule ClaperWeb.UserOidcAuthTest do
  use ClaperWeb.ConnCase, async: true

  import Phoenix.ConnTest

  describe "new/2" do
    test "redirects to the OIDC provider with a state parameter", %{conn: conn} do
      conn = get(conn, "/users/oidc")

      # Assert that we are being redirected
      assert redirected_to(conn)

      # Get the state from the session
      session_state = get_session(conn, :oidc_state)
      assert session_state

      # Get the redirect URL from the Location header
      [location] = get_resp_header(conn, "location")
      redirect_uri = URI.parse(location)

      # Get the state from the URL's query parameters
      query_params = URI.decode_query(redirect_uri.query)
      url_state = query_params["state"]

      # Assert that the state in the URL matches the state in the session
      assert url_state == session_state
    end
  end
end
