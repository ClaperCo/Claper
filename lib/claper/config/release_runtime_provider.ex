defmodule Claper.Config.ReleaseRuntimeProvider do
  @moduledoc """
  Imports runtime config or defaults to environment config.
  """
  @behaviour Config.Provider

  @impl Config.Provider
  def init(opts), do: opts

  @impl Config.Provider
  def load(config, opts) do
    with_defaults = config

    config_path =
      opts[:config_path] || System.get_env("CLAPER_CONFIG_PATH") || "/etc/claper/config.exs"

    with_runime_config =
      if File.exists?(config_path) do
        runtime_config = Config.Reader.read!(config_path)

        with_defaults
        |> Config.Reader.merge(caper: [config_path: config_path])
        |> Config.Reader.merge(runtime_config)
      else
        warning = [
          IO.ANSI.red(),
          IO.ANSI.bright(),
          "!!! Config path is not declared! Please ensure it exists and that CLAPER_CONFIG_PATH is unset or points to an existing file",
          IO.ANSI.reset()
        ]

        runtime_config =
          :code.priv_dir(:claper) |> Path.join("runtime.exs") |> Config.Reader.read!()

        IO.puts(warning)

        with_defaults
        |> Config.Reader.merge(runtime_config)
      end

    with_runime_config
  end
end
