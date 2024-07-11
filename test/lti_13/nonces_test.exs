defmodule Lti13.NoncesTest do
  use Claper.DataCase

  alias Lti13.Nonces
  alias Lti13.Nonces.Nonce

  import Lti13.UsersFixtures

  describe "nonces" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "should create new nonce with default domain nil", %{user: user} do
      {:ok, nonce} = Nonces.create_nonce(%{value: "some-value", lti_user_id: user.id})

      assert nonce.value == "some-value"
      assert nonce.domain == nil
    end

    test "should create new nonce with specified domain", %{user: user} do
      {:ok, nonce} =
        Nonces.create_nonce(%{value: "some-value", domain: "some-domain", lti_user_id: user.id})

      assert nonce.value == "some-value"
      assert nonce.domain == "some-domain"
    end

    test "should create new nonce with specified domain if one already exists with different domain",
         %{user: user} do
      {:ok, _nonce1} = Nonces.create_nonce(%{value: "some-value", lti_user_id: user.id})

      {:ok, _nonce2} =
        Nonces.create_nonce(%{value: "some-value", domain: "some-domain", lti_user_id: user.id})

      {:ok, nonce3} =
        Nonces.create_nonce(%{
          value: "some-value",
          domain: "different-domain",
          lti_user_id: user.id
        })

      assert nonce3.value == "some-value"
      assert nonce3.domain == "different-domain"
    end

    test "should fail to create new nonce if one already exists with specified domain", %{
      user: user
    } do
      {:ok, _nonce} =
        Nonces.create_nonce(%{value: "some-value", domain: "some-domain", lti_user_id: user.id})

      assert {:error, %Ecto.Changeset{}} =
               Nonces.create_nonce(%{
                 value: "some-value",
                 domain: "some-domain",
                 lti_user_id: user.id
               })
    end

    test "create and get nonce", %{user: user} do
      nonce = %{
        value: "some value",
        domain: "some domain",
        lti_user_id: user.id
      }

      assert {:ok, %Nonce{value: "some value", domain: "some domain"}} =
               Nonces.create_nonce(nonce)

      assert %Nonce{value: "some value", domain: "some domain"} =
               Nonces.get_nonce(nonce.value, nonce.domain)
    end

    test "create and get nonce without a domain", %{user: user} do
      nonce = %{
        value: "some value",
        lti_user_id: user.id
      }

      assert {:ok, %Nonce{value: "some value", domain: nil}} =
               Nonces.create_nonce(nonce)

      assert %Nonce{value: "some value", domain: nil} =
               Nonces.get_nonce(nonce.value, nil)
    end
  end
end
