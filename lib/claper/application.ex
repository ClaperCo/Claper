defmodule Claper.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []
    Oban.Telemetry.attach_default_logger()

    children = [
      {Cluster.Supervisor, [topologies, [name: Claper.ClusterSupervisor]]},
      # Start the Ecto repository
      Claper.Repo,
      # Start the Telemetry supervisor
      ClaperWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Claper.PubSub},
      # Start the rate limiter before the endpoint accepts requests
      Claper.RateLimit,
      # Start the Endpoint (http/https)
      ClaperWeb.Presence,
      ClaperWeb.Endpoint,
      # Start a worker by calling: Claper.Worker.start_link(arg)
      # {Claper.Worker, arg}
      {Finch, name: Swoosh.Finch},
      {Task.Supervisor, name: Claper.TaskSupervisor},
      {Registry, keys: :unique, name: Claper.TranscriptionRegistry},
      {DynamicSupervisor, name: Claper.TranscriptionSupervisor, strategy: :one_for_one},
      # One OIDC configuration worker per enabled provider, named from its slug.
      # They are started from the database and from the environment, so an
      # instance with no provider configured boots normally instead of failing
      # on a discovery request.
      {Claper.Accounts.Oidc.WorkerSupervisor, []},
      {Claper.Accounts.Oidc.ProviderLoader, []},
      {Oban, Application.fetch_env!(:claper, Oban)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Claper.Supervisor]

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ClaperWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
