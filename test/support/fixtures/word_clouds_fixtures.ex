defmodule Claper.WordCloudsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.WordClouds` context.
  """

  import Claper.PresentationsFixtures

  alias Claper.WordClouds.Entry

  require Claper.UtilFixture

  @doc """
  Generate a word cloud.
  """
  def word_cloud_fixture(attrs \\ %{}, preload \\ []) do
    assoc = %{presentation_file: attrs[:presentation_file] || presentation_file_fixture()}

    {:ok, word_cloud} =
      attrs
      |> Enum.into(%{
        title: "some title",
        position: 0,
        enabled: true,
        presentation_file_id: assoc.presentation_file.id
      })
      |> Claper.WordClouds.create_word_cloud()

    Claper.UtilFixture.merge_preload(word_cloud, preload, assoc)
  end

  @doc """
  Generate a word cloud entry, bypassing the checks `Claper.WordClouds.submit_entry/4`
  runs for an attendee.
  """
  def word_cloud_entry_fixture(attrs \\ %{}) do
    word_cloud = attrs[:word_cloud] || word_cloud_fixture()

    attrs =
      attrs
      |> Map.delete(:word_cloud)
      |> Enum.into(%{
        content: "some word",
        attendee_identifier: "some-attendee",
        word_cloud_id: word_cloud.id
      })

    {:ok, entry} = %Entry{} |> Entry.changeset(attrs) |> Claper.Repo.insert()

    entry
  end
end
