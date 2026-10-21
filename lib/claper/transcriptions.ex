defmodule Claper.Transcriptions do
  @moduledoc """
  The Transcriptions context.
  """

  import Ecto.Query
  alias Claper.Repo
  alias Claper.Transcriptions.Transcription
  alias Claper.Transcriptions.TranscriptionConfig

  # --- Transcription (audio segments) ---

  def list_transcriptions(presentation_file_id) do
    from(t in Transcription,
      where: t.presentation_file_id == ^presentation_file_id,
      order_by: [asc: t.inserted_at]
    )
    |> Repo.all()
  end

  def list_transcriptions_paginated(presentation_file_id, params \\ %{}) do
    query =
      from(t in Transcription,
        where: t.presentation_file_id == ^presentation_file_id
      )

    Flop.validate_and_run!(query, params, for: Transcription, replace_invalid_params: true)
  end

  def get_recent_transcriptions(presentation_file_id, limit \\ 5) do
    from(t in Transcription,
      where: t.presentation_file_id == ^presentation_file_id,
      order_by: [desc: t.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  def create_transcription(attrs) do
    %Transcription{}
    |> Transcription.changeset(attrs)
    |> Repo.insert()
  end

  def delete_transcriptions_for_presentation(presentation_file_id) do
    from(t in Transcription, where: t.presentation_file_id == ^presentation_file_id)
    |> Repo.delete_all()
  end

  def broadcast_transcription(event_uuid, transcription) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {:transcription_created, transcription}
    )
  end

  def broadcast_transcription_delta(event_uuid, text) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {:transcription_delta, text}
    )
  end

  # --- TranscriptionConfig ---

  def get_transcription_config(presentation_file_id) do
    Repo.get_by(TranscriptionConfig, presentation_file_id: presentation_file_id)
  end

  @doc """
  Gets a transcription config scoped to the given event.

  Returns `nil` if the config does not exist or does not belong to the event.
  """
  def get_transcription_config_for_event(id, event_id) do
    from(c in TranscriptionConfig,
      join: pf in assoc(c, :presentation_file),
      where: c.id == ^id and pf.event_id == ^event_id
    )
    |> Repo.one()
  end

  def create_transcription_config(attrs) do
    %TranscriptionConfig{}
    |> TranscriptionConfig.changeset(attrs)
    |> Repo.insert()
  end

  def update_transcription_config(event_uuid, config, attrs) do
    result =
      config
      |> TranscriptionConfig.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_config} ->
        Phoenix.PubSub.broadcast(
          Claper.PubSub,
          "event:#{event_uuid}",
          {:transcription_config_updated, updated_config}
        )

        {:ok, updated_config}

      error ->
        error
    end
  end

  def delete_transcription_config(event_uuid, config) do
    result = Repo.delete(config)

    case result do
      {:ok, deleted_config} ->
        Phoenix.PubSub.broadcast(
          Claper.PubSub,
          "event:#{event_uuid}",
          {:transcription_config_deleted, deleted_config}
        )

        {:ok, deleted_config}

      error ->
        error
    end
  end

  def change_transcription_config(config, attrs \\ %{}) do
    TranscriptionConfig.changeset(config, attrs)
  end

  def set_transcription_enabled(%TranscriptionConfig{} = config) do
    config
    |> TranscriptionConfig.changeset(%{enabled: true})
    |> Repo.update()
  end

  def set_transcription_disabled(%TranscriptionConfig{} = config) do
    config
    |> TranscriptionConfig.changeset(%{enabled: false})
    |> Repo.update()
  end
end
