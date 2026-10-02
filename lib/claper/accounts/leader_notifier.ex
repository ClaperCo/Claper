defmodule Claper.Accounts.LeaderNotifier do
  def deliver_event_invitation(event_name, email, url) do
    locale =
      case Claper.Accounts.get_user_by_email(email) do
        %{locale: locale} when is_binary(locale) -> locale
        _ -> Gettext.get_locale(ClaperWeb.Gettext)
      end

    Claper.Workers.Mailers.event_invitation(event_name, email, url, locale) |> Oban.insert()

    {:ok, :enqueued}
  end
end
