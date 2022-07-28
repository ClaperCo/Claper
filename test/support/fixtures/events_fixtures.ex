defmodule Claper.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Events` context.
  """

  import Claper.{AccountsFixtures}

  require Claper.UtilFixture

  @doc """
  Generate a event.
  """
  def event_fixture(attrs \\ %{}, preload \\ []) do
    assoc = %{user: attrs[:user] || user_fixture()}
    {:ok, event} =
      attrs
      |> Enum.into(%{
        name: "some name",
        code: "#{Enum.random(1000..2000)}",
        uuid: Ecto.UUID.generate(),
        user_id: assoc.user.id,
        started_at: NaiveDateTime.utc_now,
        expired_at: NaiveDateTime.add(NaiveDateTime.utc_now, 7200, :second) # add 2 hours
      })
      |> Claper.Events.create_event()

      Claper.UtilFixture.merge_preload(event, preload, assoc)
  end

end
