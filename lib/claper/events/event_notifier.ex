defmodule Claper.Events.EventNotifier do
  alias Claper.{Repo, Stats}
  alias Claper.Events.Event
  alias Claper.Workers.Mailers

  @doc """
  Emails the owner of an ended event its recap, when `recap?/1`. `ended_by` is
  `:manual` when the owner terminated the event, `:inactivity` when it was terminated
  for inactivity.
  """
  def deliver_recap(%Event{} = event, ended_by) do
    event = Repo.preload(event, :user)

    if recap?(event) do
      event.id
      |> Mailers.new_event_recap(
        ended_by,
        event.user.locale || Gettext.get_locale(ClaperWeb.Gettext)
      )
      |> Oban.insert()

      {:ok, :enqueued}
    else
      {:ok, :skipped}
    end
  end

  @doc """
  Returns whether the owner of an ended event gets its recap: someone attended the
  event and the owner's account isn't deleted.
  """
  def recap?(%Event{} = event) do
    case Repo.preload(event, :user).user do
      %{deleted_at: nil} -> Stats.get_unique_attendees_for_event(event.id) > 0
      _deleted -> false
    end
  end
end
