defmodule Claper.Accounts.Oidc.WorkerSupervisor do
  @moduledoc """
  Supervises one `Oidcc.ProviderConfiguration.Worker` per enabled OIDC provider.

  Every worker is registered under a name derived from the provider slug, so the
  authentication flow can address one provider out of several by URL, and so a
  provider that is edited or disabled in the admin can be restarted or stopped
  without touching the others.

  The name is an atom, not a `Registry` key: `oidcc` resolves the configuration
  worker with `:erlang.whereis/1`, which only accepts an atom, and
  `Oidcc.ProviderConfiguration.Worker` itself requires an atom name. One atom
  per provider, and providers are created by an administrator, so the number of
  atoms stays bounded.
  """
  use DynamicSupervisor

  alias Claper.Accounts.Oidc.Provider

  @worker_prefix "Claper.OidcProviderConfig"
  @legacy_slug "default"

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)

  @doc """
  Registered name of the configuration worker of a provider slug.
  """
  def worker_name(slug) when is_binary(slug), do: :"#{@worker_prefix}.#{slug}"

  def worker_name(%Provider{slug: slug}), do: worker_name(slug)

  @doc """
  Starts the configuration worker of a provider, unless it already runs.
  """
  def start_provider(%Provider{} = provider), do: start(provider.slug, provider.issuer)

  @doc """
  Starts the provider described by the environment variables under the `default`
  slug, unless a configured provider already serves the same issuer.
  """
  def start_legacy_provider(issuer) when is_binary(issuer) do
    if Enum.any?(Claper.Accounts.Oidc.list_active_providers(), &(&1.issuer == issuer)) do
      :ok
    else
      start(@legacy_slug, issuer)
    end
  end

  @doc """
  Stops the configuration worker of a provider.
  """
  def stop_provider(%Provider{} = provider), do: stop(provider.slug)

  @doc """
  Returns the pid of the configuration worker of a slug, or nil.
  """
  def whereis(slug) when is_binary(slug) do
    Process.whereis(worker_name(slug))
  end

  def whereis(%Provider{} = provider), do: whereis(provider.slug)

  @doc """
  Stops every configuration worker.
  """
  def stop_all do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn {_id, pid, _type, _modules} ->
      DynamicSupervisor.terminate_child(__MODULE__, pid)
    end)

    :ok
  end

  defp start(slug, issuer) do
    spec = {Oidcc.ProviderConfiguration.Worker, %{issuer: issuer, name: worker_name(slug)}}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  defp stop(slug) do
    case whereis(slug) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end
end
