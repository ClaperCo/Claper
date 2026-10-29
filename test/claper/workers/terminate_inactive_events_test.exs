defmodule Claper.Workers.TerminateInactiveEventsTest do
  use Claper.DataCase

  import Claper.EventsFixtures
  import Lti13.RegistrationsFixtures

  alias Claper.Events
  alias Claper.Events.Event
  alias Claper.Workers.{Mailers, TerminateInactiveEvents}

  # config/runtime.exs sets the delay from EVENT_INACTIVITY_DAYS.
  setup do
    events_config = Application.get_env(:claper, :events)
    Application.put_env(:claper, :events, inactivity_days: 14)
    on_exit(fn -> Application.put_env(:claper, :events, events_config) end)
  end

  defp days_from_now(days), do: NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(days, :day)

  # An event started, updated and last visited `days` ago, unless `overrides` says otherwise.
  defp event_inactive_for(days, overrides \\ []),
    do: event_inactive_since(days_from_now(-days), overrides)

  defp event_inactive_since(at, overrides \\ []) do
    event = event_fixture()

    from(e in Event, where: e.id == ^event.id)
    |> Repo.update_all(
      set: Keyword.merge([started_at: at, updated_at: at, last_active_at: at], overrides)
    )

    Repo.reload!(event)
  end

  defp terminated?(event), do: not is_nil(Repo.reload!(event).expired_at)

  test "terminates events inactive for longer than the configured days and frees their code" do
    inactive = event_inactive_for(15)
    recent = event_inactive_for(13)
    Events.subscribe_event(inactive.uuid)

    assert :ok = perform_job(TerminateInactiveEvents, %{})

    assert terminated?(inactive)
    refute terminated?(recent)
    assert_received {:event_terminated, uuid}
    assert uuid == inactive.uuid
    assert %Event{} = event_fixture(%{code: inactive.code})
  end

  test "keeps events visited, updated or starting after the cutoff" do
    visited = event_inactive_for(30)
    :ok = Events.record_event_activity(visited)

    updated = event_inactive_for(30, updated_at: days_from_now(-1))
    scheduled = event_inactive_for(30, started_at: days_from_now(7))

    assert :ok = perform_job(TerminateInactiveEvents, %{})

    refute terminated?(visited)
    refute terminated?(updated)
    refute terminated?(scheduled)
  end

  test "keeps events that have an end date or an LTI resource" do
    end_date = days_from_now(7)
    with_end_date = event_inactive_for(30, expired_at: end_date)
    linked = event_inactive_for(30)

    {:ok, _} =
      Lti13.Resources.create_resource(%{
        title: "Course",
        resource_id: 1,
        registration_id: registration_fixture().id,
        event_id: linked.id
      })

    assert :ok = perform_job(TerminateInactiveEvents, %{})

    assert Repo.reload!(with_end_date).expired_at == end_date
    refute terminated?(linked)
  end

  test "terminates nothing when the delay is 0" do
    Application.put_env(:claper, :events, inactivity_days: 0)
    inactive = event_inactive_for(365)

    assert :ok = perform_job(TerminateInactiveEvents, %{})

    refute terminated?(inactive)
  end

  test "emails a recap for events that just became inactive, not for long abandoned ones" do
    Oban.Testing.with_testing_mode(:manual, fn ->
      just_inactive = event_inactive_since(NaiveDateTime.add(days_from_now(-14), -1, :hour))
      abandoned = event_inactive_for(60)

      for event <- [just_inactive, abandoned],
          do: Claper.Stats.create_stat(event, %{attendee_identifier: "attendee"})

      assert :ok = perform_job(TerminateInactiveEvents, %{})

      assert_enqueued(
        worker: Mailers,
        args: %{type: "event_recap", event_id: just_inactive.id, ended_by: "inactivity"}
      )

      refute_enqueued(worker: Mailers, args: %{type: "event_recap", event_id: abandoned.id})
      assert terminated?(abandoned)
    end)
  end

  test "preview/1 tells what a run would terminate and email, without changing anything" do
    Oban.Testing.with_testing_mode(:manual, fn ->
      just_inactive = event_inactive_since(NaiveDateTime.add(days_from_now(-14), -1, :hour))
      abandoned = event_inactive_for(60)
      recent = event_inactive_for(3)

      for event <- [just_inactive, abandoned, recent],
          do: Claper.Stats.create_stat(event, %{attendee_identifier: "attendee"})

      assert TerminateInactiveEvents.preview(14) == %{terminated: 2, recaps: 1}
      refute terminated?(just_inactive) or terminated?(abandoned)

      assert :ok = perform_job(TerminateInactiveEvents, %{})

      assert terminated?(just_inactive) and terminated?(abandoned)
      refute terminated?(recent)
      assert [_recap] = all_enqueued(worker: Mailers)
    end)
  end
end
