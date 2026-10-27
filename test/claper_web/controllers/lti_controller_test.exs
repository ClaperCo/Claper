defmodule ClaperWeb.LtiControllerTest do
  use ClaperWeb.ConnCase, async: true

  import Lti13.JwksFixtures

  describe "GET /.well-known/jwks.json" do
    test "publishes only the public part of the tool keys", %{conn: conn} do
      {:ok, _} = Claper.Settings.set("lti_enabled", "true")
      key = JOSE.JWK.generate_key({:rsa, 2048})
      {_, pem} = JOSE.JWK.to_pem(key)
      {_, %{"n" => modulus}} = key |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()
      jwk_fixture(%{pem: pem, kid: "tool-key", alg: "RS256", typ: "JWT"})

      conn = get(conn, ~p"/.well-known/jwks.json")

      assert [published] = json_response(conn, 200)["keys"]
      assert %{"kid" => "tool-key", "alg" => "RS256", "use" => "sig", "n" => ^modulus} = published
      refute Map.has_key?(published, "d")
    end
  end
end
