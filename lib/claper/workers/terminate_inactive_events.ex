defmodule Claper.Workers.TerminateInactiveEvents do
  @moduledoc """
  Terminates the events that have had no activity for `EVENT_INACTIVITY_DAYS`
  days, so that new events can use their codes. Disabled when it is `0`, the default.

  Scheduled every hour by `Oban.Plugins.Cron`.
  """
  use Oban.Worker, queue: :default

  alias Claper.Events

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case Events.inactivity_days() do
      days when days > 0 ->
        days |> inactive_since() |> Events.terminate_inactive_events()
        :ok

      _disabled ->
        :ok
    end
  end

  @doc """
  Returns what a run would do right now with `EVENT_INACTIVITY_DAYS` set to `days`,
  without changing anything. Check it on the running release before setting it:

      bin/claper rpc "IO.inspect(Claper.Workers.TerminateInactiveEvents.preview(14))"
      %{terminated: 1250, recaps: 4}

  """
  def preview(days) when is_integer(days) and days > 0 do
    days |> inactive_since() |> Events.preview_inactive_events()
  end

  defp inactive_since(days), do: NaiveDateTime.utc_now() |> NaiveDateTime.add(-days, :day)
end
