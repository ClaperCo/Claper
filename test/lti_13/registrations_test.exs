defmodule Lti13.RegistrationsTest do
  use Claper.DataCase

  alias Lti13.Registrations

  import Lti13.JwksFixtures

  describe "registrations" do
    test "create and get registration by issuer client id" do
      jwk = jwk_fixture()

      registration = %{
        issuer: "some issuer",
        client_id: "some client_id",
        key_set_url: "some key_set_url",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        tool_jwk_id: jwk.id
      }

      assert {:ok,
              %Registrations.Registration{issuer: "some issuer", client_id: "some client_id"}} =
               Registrations.create_registration(registration)

      assert %Registrations.Registration{issuer: "some issuer", client_id: "some client_id"} =
               Registrations.get_registration_by_issuer_client_id("some issuer", "some client_id")
    end
  end
end
