defmodule Claper.MixProject do
  use Mix.Project

  @version "2.4.0"

  def project do
    [
      app: :claper,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # Docs
      name: "Claper",
      source_url: "https://github.com/ClaperCo/Claper",
      homepage_url: "https://claper.co",
      docs: [
        logo: "priv/static/images/logo.png",
        groups_for_modules: [
          "User management": [
            ~r/Claper\.Account\.?/,
            ~r/ClaperWeb\.UserRegistration\.?/,
            ~r/ClaperWeb\.UserSession\.?/,
            ~r/ClaperWeb\.UserLiveAuth\.?/,
            ~r/ClaperWeb\.UserConfirmation\.?/,
            ~r/ClaperWeb\.UserSettings\.?/,
            ~r/ClaperWeb\.UserReset\.?/,
            ~r/ClaperWeb\.Attendee\.?/,
            ~r/ClaperWeb\.UserAuth\.?/,
            ~r/ClaperWeb\.UserView\.?/
          ],
          Events: [
            ~r/Claper\.Event\.?/,
            ~r/ClaperWeb\.Event\.?/
          ],
          Forms: [
            ~r/Claper\.Forms\.?/,
            ~r/ClaperWeb\.Form\.?/
          ],
          WebContent: [
            ~r/Claper\.Embed\.?/,
            ~r/ClaperWeb\.Embed\.?/
          ],
          Polls: [
            ~r/Claper\.Polls\.?/,
            ~r/ClaperWeb\.Poll\.?/
          ],
          Posts: [
            ~r/Claper\.Posts\.?/,
            ~r/ClaperWeb\.Post\.?/
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Claper.Application, []},
      extra_applications: [:logger, :runtime_tools, :ssl, :porcelain]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:bcrypt_elixir, "~> 3.3"},
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.20.0"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_swoosh, "~> 1.2.1"},
      {:phoenix_view, "~> 2.0"},
      {:floki, ">= 0.36.1", only: :test},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:dart_sass, "~> 0.7", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.19"},
      {:finch, "~> 0.19"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.2"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.4"},
      {:sweet_xml, "~> 0.7"},
      {:plug_cowboy, "~> 2.7"},
      {:hashids, "~> 2.1"},
      {:libcluster, "~> 3.5"},
      {:porcelain, "~> 2.0"},
      {:hackney, "~> 1.24"},
      {:csv, "~> 3.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:joken, "~> 2.6"},
      {:jose, "~> 1.11"},
      {:req, "~> 0.5"},
      {:uuid, "~> 1.1"},
      {:oidcc, "~> 3.5"},
      {:oban, "~> 2.19"},
      {:mua, "~> 0.2"},
      {:mail, "~> 0.5"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        "cmd --cd assets npm install",
        "tailwind default --minify",
        "tailwind admin --minify",
        "esbuild default --minify",
        "sass default --no-source-map --style=compressed",
        "phx.digest"
      ]
    ]
  end
end
