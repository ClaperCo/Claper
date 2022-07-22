defmodule Claper.PresentationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Presentations` context.
  """

  import Claper.{EventsFixtures}

  require Claper.UtilFixture

  @doc """
  Generate a presentation_file.
  """
  def presentation_file_fixture(attrs \\ %{}, preload \\ []) do
    assoc = %{event: event_fixture()}
    {:ok, presentation_file} =
      attrs
      |> Enum.into(%{
        hash: "123456",
        length: 42,
        status: "done",
        event_id: assoc.event.id
      })
      |> Claper.Presentations.create_presentation_file()

      Claper.UtilFixture.merge_preload(presentation_file, preload, assoc)
  end

  @doc """
  Generate a presentation_state.
  """
  def presentation_state_fixture(attrs \\ %{}) do
    assoc = %{presentation_file: presentation_file_fixture()}
    {:ok, presentation_state} =
      attrs
      |> Enum.into(%{
        presentation_file_id: assoc.presentation_file.id,
        position: 0,
        chat_visible: false,
        poll_visible: false,
        join_screen_visible: false
      })
      |> Claper.Presentations.create_presentation_state()

    presentation_state
  end
end
