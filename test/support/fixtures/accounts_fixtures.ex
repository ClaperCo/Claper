defmodule Claper.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      confirmed_at: NaiveDateTime.utc_now()
    })
  end

  def no_valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> no_valid_user_attributes()
      |> Claper.Accounts.register_user()

    user
  end

  def confirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Claper.Accounts.register_user()

    user
  end
end
