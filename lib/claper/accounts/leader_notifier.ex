defmodule Claper.Accounts.LeaderNotifier do
  alias Claper.Mailer

  def deliver_event_invitation(event_name, email, url) do
    e = ClaperWeb.Notifiers.LeaderNotifier.event_invitation(event_name, email, url)

    with {:ok, _metadata} <- Mailer.deliver(e) do
      {:ok, email}
    end
  end

end
