defmodule Claper.Accounts.Oidc.ProviderLoader do
  @moduledoc """
  Starts the OIDC configuration workers at boot, and again whenever the admin
  changes a provider.

  It runs as a temporary task so that a provider which cannot be reached, or a
  database which is not ready yet, is logged instead of taking the application
  down with it. That also means an instance with no provider configured boots
  normally, which was not the case when the provider worker was started
  unconditionally from the environment configuration.
  """
  require Logger

  alias Claper.Accounts.Oidc
  alias Claper.Accounts.Oidc.WorkerSupervisor

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {Task, :start_link, [&reload/0]},
      restart: :temporary,
      shutdown: 5_000,
      type: :worker
    }
  end

  @doc """
  Restarts every configuration worker from the current provider list.
  """
  def reload do
    WorkerSupervisor.stop_all()
    load_configured_providers()
    load_legacy_provider()
    :ok
  rescue
    error ->
      Logger.error("could not load the OIDC providers: #{inspect(error)}")
      :ok
  end

  defp load_configured_providers do
    for provider <- Oidc.list_active_providers() do
      case WorkerSupervisor.start_provider(provider) do
        {:ok, _pid} ->
          :ok

        {:error, reason} ->
          Logger.error("could not start the OIDC provider #{provider.slug}: #{inspect(reason)}")
      end
    end
  end

  defp load_legacy_provider do
    config = Application.get_env(:claper, :oidc) || []

    if config[:enabled] && is_binary(config[:issuer]) do
      case WorkerSupervisor.start_legacy_provider(config[:issuer]) do
        {:ok, _pid} ->
          :ok

        {:error, reason} ->
          Logger.error(
            "could not start the OIDC provider from the environment: #{inspect(reason)}"
          )
      end
    end

    :ok
  end
end
