defmodule ClaperWeb.LtiControllerTest do
  use ClaperWeb.ConnCase, async: true

  describe "GET /.well-known/jwks.json" do
    test "returns the public key", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/jwks.json")
      response = json_response(conn, 200)
      assert response["keys"]
    end
  end
end
