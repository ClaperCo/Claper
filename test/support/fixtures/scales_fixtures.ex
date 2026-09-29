defmodule Claper.ScalesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Scales` context.
  """

  import Claper.PresentationsFixtures

  alias Claper.Scales.ScaleResponse

  require Claper.UtilFixture

  @doc """
  Generate a scale.
  """
  def scale_fixture(attrs \\ %{}, preload \\ []) do
    assoc = %{presentation_file: attrs[:presentation_file] || presentation_file_fixture()}

    {:ok, scale} =
      attrs
      |> Enum.into(%{
        title: "some title",
        min_value: 1,
        max_value: 10,
        step: 1,
        position: 0,
        enabled: true,
        presentation_file_id: assoc.presentation_file.id
      })
      |> Claper.Scales.create_scale()

    Claper.UtilFixture.merge_preload(scale, preload, assoc)
  end

  @doc """
  Generate a scale response, bypassing the checks `Claper.Scales.submit_response/4`
  runs for an attendee.
  """
  def scale_response_fixture(attrs \\ %{}) do
    scale = attrs[:scale] || scale_fixture()

    attrs =
      attrs
      |> Map.delete(:scale)
      |> Enum.into(%{value: scale.min_value, attendee_identifier: "some-attendee"})

    {:ok, response} =
      %ScaleResponse{} |> ScaleResponse.changeset(attrs, scale) |> Claper.Repo.insert()

    response
  end
end
