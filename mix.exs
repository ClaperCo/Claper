defmodule Claper.MixProject do
  use Mix.Project

  @version "1.2.2"

  def project do
    [
      app: :claper,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # Docs
      name: "Claper",
      source_url: "https://github.com/ClaperCo/Claper",
      homepage_url: "https://get.claper.co",
      docs: [
        main: "overview",
        assets: "guides/assets",
        logo: "priv/static/images/logo.png",
        extra_section: "GUIDES",
        extras: [
          "guides/introduction/overview.md",
          "guides/introduction/configuration.md",
          "guides/introduction/installation.md",
          "guides/introduction/deployment.md",
          "guides/introduction/storage.md",
          "guides/usage/features.md",
          "guides/usage/howto.md"
        ],
        groups_for_extras: [
          Introduction: ~r/guides\/introduction\/.?/,
          Guides: ~r/guides\/[^\/]+\.md/,
          Usage: ~r/guides\/usage\/.?/
        ],
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
      {:ex_aws, "~> 2.2"},
      {:ex_aws_s3, "~> 2.3"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:bcrypt_elixir, "~> 2.0"},
      {:phoenix, "~> 1.6.2"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.0"},
      {:phoenix_swoosh, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},
      {:dart_sass, "~> 0.5", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.8"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:sweet_xml, "~> 0.7.1"},
      {:plug_cowboy, "~> 2.5"},
      {:hashids, "~> 2.0"},
      {:mogrify, "~> 0.9.1"},
      {:libcluster, "~> 3.3"},
      {:porcelain, "~> 2.0"},
      {:hackney, "~> 1.18"},
      {:gen_smtp, "~> 1.2"},
      {:csv, "~> 3.0"}
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
        "cmd --cd assets npm install && npm run deploy",
        "esbuild default --minify",
        "sass default --no-source-map --style=compressed",
        "phx.digest"
      ]
    ]
  end
end
