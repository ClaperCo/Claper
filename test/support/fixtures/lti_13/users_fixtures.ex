defmodule Lti13.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lti13.Users` context.
  """


  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    claper_user = Claper.AccountsFixtures.user_fixture()
    registration = Lti13.RegistrationsFixtures.registration_fixture()

    {:ok, user} =
      attrs
      |> Enum.into(%{
        sub: "a6d5c443-1f51-4783-ba1a-7686ffe3b54a",
        name: "John Doe",
        email: "john#{System.unique_integer([:positive])}@doe.edu",
        user_id: claper_user.id,
        registration_id: registration.id,
        roles: [
          "http://purl.imsglobal.org/vocab/lis/v2/system/person#User",
          "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student"
        ]
      })
      |> Lti13.Users.create_user()

    user
  end
end
