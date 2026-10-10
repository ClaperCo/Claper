defmodule Claper.Accounts.LeaderNotifierTest do
  use Claper.DataCase

  import Claper.AccountsFixtures

  alias Claper.Accounts
  alias Claper.Accounts.LeaderNotifier
  alias Claper.Workers.Mailers

  @url "http://localhost/events"

  setup do
    Gettext.put_locale(ClaperWeb.Gettext, "de")
    :ok
  end

  test "invites an existing user in their stored locale" do
    {:ok, user} = Accounts.update_user_preferences(user_fixture(), %{locale: "fr"})

    Oban.Testing.with_testing_mode(:manual, fn ->
      LeaderNotifier.deliver_event_invitation("Town hall", user.email, @url)

      assert_enqueued(worker: Mailers, args: %{email: user.email, locale: "fr"})
    end)
  end

  test "invites an address without an account in the request locale" do
    Oban.Testing.with_testing_mode(:manual, fn ->
      LeaderNotifier.deliver_event_invitation("Town hall", "guest@example.com", @url)

      assert_enqueued(worker: Mailers, args: %{email: "guest@example.com", locale: "de"})
    end)
  end
end
