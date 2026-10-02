defmodule Claper.Accounts.UserNotifierTest do
  use Claper.DataCase

  import Claper.AccountsFixtures

  alias Claper.Accounts
  alias Claper.Accounts.UserNotifier
  alias Claper.Workers.Mailers

  @url "http://localhost/users/reset_password/token"

  setup do
    Gettext.put_locale(ClaperWeb.Gettext, "de")
    :ok
  end

  test "sends user emails in the user's stored locale" do
    {:ok, user} = Accounts.update_user_preferences(user_fixture(), %{locale: "fr"})

    Oban.Testing.with_testing_mode(:manual, fn ->
      UserNotifier.deliver_confirmation_instructions(user, @url)
      UserNotifier.deliver_reset_password_instructions(user, @url)
      UserNotifier.deliver_update_email_instructions(user, @url)

      assert_enqueued(worker: Mailers, args: %{type: "confirm", locale: "fr"})
      assert_enqueued(worker: Mailers, args: %{type: "reset", locale: "fr"})
      assert_enqueued(worker: Mailers, args: %{type: "update_email", locale: "fr"})
    end)
  end

  test "sends user emails in the request locale when the user has none stored" do
    user = user_fixture()

    Oban.Testing.with_testing_mode(:manual, fn ->
      UserNotifier.deliver_reset_password_instructions(user, @url)

      assert_enqueued(worker: Mailers, args: %{type: "reset", locale: "de"})
    end)
  end

  test "sends a magic link for an existing account in its stored locale" do
    {:ok, user} = Accounts.update_user_preferences(user_fixture(), %{locale: "fr"})

    Oban.Testing.with_testing_mode(:manual, fn ->
      UserNotifier.deliver_magic_link(user.email, @url)

      assert_enqueued(worker: Mailers, args: %{type: "magic", locale: "fr"})
    end)
  end

  test "sends emails to a bare address in the request locale" do
    Oban.Testing.with_testing_mode(:manual, fn ->
      UserNotifier.deliver_magic_link("someone@example.com", @url)
      UserNotifier.deliver_welcome("someone@example.com")

      assert_enqueued(worker: Mailers, args: %{type: "magic", locale: "de"})
      assert_enqueued(worker: Mailers, args: %{type: "welcome", locale: "de"})
    end)
  end
end
