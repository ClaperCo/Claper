defmodule Claper.Workers.MailersTest do
  use Claper.DataCase

  import Claper.AccountsFixtures
  import Swoosh.TestAssertions

  alias Claper.Workers.Mailers

  @url "http://localhost/users/reset_password/token"

  # config/runtime.exs replaces the test adapter with the one MAIL_TRANSPORT selects.
  setup do
    mailer_config = Application.get_env(:claper, Claper.Mailer)
    Application.put_env(:claper, Claper.Mailer, adapter: Swoosh.Adapters.Test)
    on_exit(fn -> Application.put_env(:claper, Claper.Mailer, mailer_config) end)
  end

  test "builds the email in the locale from the job args" do
    user = user_fixture()

    perform_job(Mailers, %{type: "reset", user_id: user.id, url: @url, locale: "fr"})

    assert_email_sent(subject: "Instructions de réinitialisation du mot de passe")
  end

  test "builds emails without a user in the locale from the job args" do
    perform_job(Mailers, %{
      type: "event_invitation",
      event_name: "Town hall",
      email: "leader@example.com",
      url: "http://localhost/events",
      locale: "fr"
    })

    assert_email_sent(subject: "Vous avez été invité à gérer un événement")
  end

  test "delivers jobs without a locale in the default locale" do
    user = user_fixture()

    perform_job(Mailers, %{type: "reset", user_id: user.id, url: @url})

    assert_email_sent(subject: "Reset password instructions")
  end

  test "builds the recap of an event ended for inactivity for its owner" do
    owner = user_fixture()
    event = Claper.EventsFixtures.event_fixture(%{user: owner, name: "Town hall"})
    {:ok, event} = Claper.Events.update_event(event, %{audience_peak: 123})

    events_config = Application.get_env(:claper, :events)
    Application.put_env(:claper, :events, inactivity_days: 21)
    on_exit(fn -> Application.put_env(:claper, :events, events_config) end)

    perform_job(Mailers, %{
      type: "event_recap",
      event_id: event.id,
      ended_by: "inactivity",
      locale: "en"
    })

    assert_email_sent(fn email ->
      assert email.to == [{"", owner.email}]
      assert email.subject =~ "Town hall"
      assert email.html_body =~ "21 days"
      assert email.html_body =~ event.code
      assert email.html_body =~ "123"
      assert email.html_body =~ "/events/#{event.uuid}/stats"
    end)
  end
end
