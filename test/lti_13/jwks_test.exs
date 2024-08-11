defmodule Lti13.JwksTest do
  use Claper.DataCase

  alias Lti13.Jwks.Jwk

  import Lti13.JwksFixtures
  import Lti13.RegistrationsFixtures

  describe "jwks" do
    test "create and get active jwk" do
      %{private_key: private_key} = Lti13.Jwks.Utils.KeyGenerator.generate_key_pair()

      jwk = %{
        pem: private_key,
        typ: "JWT",
        alg: "RS256",
        kid: UUID.uuid4(),
        active: true
      }

      assert {:ok, %Jwk{pem: ^private_key, active: true}} = Lti13.Jwks.create_jwk(jwk)
      assert %Jwk{pem: ^private_key, active: true} = Lti13.Jwks.get_active_jwk()
    end

    test "create and get all jwks" do
      {:ok, _} =
        Lti13.Jwks.create_jwk(%{
          pem: Lti13.Jwks.Utils.KeyGenerator.generate_key_pair().private_key,
          typ: "JWT",
          alg: "RS256",
          kid: UUID.uuid4(),
          active: true
        })

      active_jwk = Lti13.Jwks.get_active_jwk()
      %{private_key: private_key} = Lti13.Jwks.Utils.KeyGenerator.generate_key_pair()

      jwk1 = %{
        pem: private_key,
        typ: "JWT",
        alg: "RS256",
        kid: UUID.uuid4(),
        active: false
      }

      jwk2 = %{
        pem: private_key,
        typ: "JWT",
        alg: "RS256",
        kid: UUID.uuid4(),
        active: false
      }

      jwk3 = %{
        pem: private_key,
        typ: "JWT",
        alg: "RS256",
        kid: UUID.uuid4(),
        active: false
      }

      assert {:ok, %Jwk{}} = Lti13.Jwks.create_jwk(jwk1)
      assert {:ok, %Jwk{}} = Lti13.Jwks.create_jwk(jwk2)
      assert {:ok, %Jwk{}} = Lti13.Jwks.create_jwk(jwk3)

      all_jwks = Lti13.Jwks.get_all_jwks()
      assert Enum.any?(all_jwks, fn jwk -> jwk.kid == active_jwk.kid end)
      assert Enum.any?(all_jwks, fn jwk -> jwk.kid == jwk1.kid end)
      assert Enum.any?(all_jwks, fn jwk -> jwk.kid == jwk2.kid end)
      assert Enum.any?(all_jwks, fn jwk -> jwk.kid == jwk3.kid end)
    end

    test "get jwk by registration" do
      jwk = jwk_fixture()
      jwk_id = jwk.id
      registration = registration_fixture(%{tool_jwk_id: jwk_id})

      assert %Jwk{id: ^jwk_id} = Lti13.Jwks.get_jwk_by_registration(registration)
    end
  end
end
