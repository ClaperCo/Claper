defmodule Claper.Workers.Mailers do
  use Oban.Worker, queue: :mailers

  alias Claper.Mailer
  alias ClaperWeb.Notifiers.{UserNotifier, LeaderNotifier}

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Jobs still queued from before an upgrade have no locale in their args.
    locale = Map.get(args, "locale", Gettext.get_locale(ClaperWeb.Gettext))

    email = Gettext.with_locale(ClaperWeb.Gettext, locale, fn -> build_email(args) end)
    Mailer.deliver(email)
  end

  defp build_email(%{"type" => type, "user_id" => user_id, "url" => url})
       when type in ["confirm", "reset"] do
    user = Claper.Accounts.get_user!(user_id)

    case type do
      "confirm" -> UserNotifier.confirm(user, url)
      "reset" -> UserNotifier.reset(user, url)
    end
  end

  defp build_email(%{"type" => "update_email", "new_email" => new_email, "url" => url}) do
    UserNotifier.update_email(new_email, url)
  end

  defp build_email(%{"type" => "magic", "email" => email, "url" => url}) do
    UserNotifier.magic(email, url)
  end

  defp build_email(%{"type" => "welcome", "email" => email}) do
    UserNotifier.welcome(email)
  end

  defp build_email(%{
         "type" => "event_invitation",
         "event_name" => event_name,
         "email" => email,
         "url" => url
       }) do
    LeaderNotifier.event_invitation(event_name, email, url)
  end

  # Helper functions to create jobs
  def new_confirmation(user_id, url, locale) do
    new(%{type: "confirm", user_id: user_id, url: url, locale: locale})
  end

  def new_reset_password(user_id, url, locale) do
    new(%{type: "reset", user_id: user_id, url: url, locale: locale})
  end

  def new_update_email(new_email, url, locale) do
    new(%{type: "update_email", new_email: new_email, url: url, locale: locale})
  end

  def new_magic_link(email, url, locale) do
    new(%{type: "magic", email: email, url: url, locale: locale})
  end

  def new_welcome(email, locale) do
    new(%{type: "welcome", email: email, locale: locale})
  end

  def event_invitation(event_name, email, url, locale) do
    new(%{
      type: "event_invitation",
      event_name: event_name,
      email: email,
      url: url,
      locale: locale
    })
  end
end
