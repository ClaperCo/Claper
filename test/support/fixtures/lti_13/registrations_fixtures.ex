defmodule Lti13.RegistrationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lti13.Registrations` context.
  """

  import Lti13.JwksFixtures

  @doc """
  Generate a registration.
  """
  def registration_fixture(attrs \\ %{}) do
    jwk = jwk_fixture()

    {:ok, registration} =
      attrs
      |> Enum.into(%{
        issuer: "https://example.com",
        client_id: UUID.uuid4(),
        auth_token_url: "https://example.com/auth_token_url",
        auth_login_url: "https://example.com/auth_login_url",
        key_set_url: "https://example.com/key_set_url",
        auth_server: "https://example.com/",
        tool_jwk_id: attrs[:tool_jwk_id] || jwk.id
      })
      |> Lti13.Registrations.create_registration()

    registration
  end
end
