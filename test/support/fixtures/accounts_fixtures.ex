defmodule Claper.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      confirmed_at: NaiveDateTime.utc_now(),
    })
  end

  def no_valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email()
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

  def extract_magic_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.html_body, "[TOKEN]")
    token
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.html_body || captured_email.text_body, "[TOKEN]")
    token
  end
end
