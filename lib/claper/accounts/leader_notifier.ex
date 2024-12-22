defmodule Claper.Accounts.LeaderNotifier do

  def deliver_event_invitation(event_name, email, url) do
    Claper.Workers.Mailers.event_invitation(event_name, email, url) |> Oban.insert()

    {:ok, :enqueued}
  end
end
