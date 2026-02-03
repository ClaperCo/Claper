defmodule Claper.AuditFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Audit` context.
  """

  @doc """
  Generate a log.
  """
  def log_fixture(attrs \\ %{}) do
    {:ok, log} =
      attrs
      |> Enum.into(%{
        action: "some action",
        metadata: %{},
        resource_id: 42,
        resource_type: "some resource_type"
      })
      |> Claper.Audit.create_log()

    log
  end
end
