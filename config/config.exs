# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :claper,
  ecto_repos: [Claper.Repo]

# Configures the endpoint
config :claper, ClaperWeb.Endpoint,
  render_errors: [view: ClaperWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Claper.PubSub,
  live_view: [signing_salt: "DN0vwriJgVkHG0kn3hF5JKho/DE66onv"]

config :claper, ClaperWeb.Gettext,
  default_locale: "en",
  locales: ~w(fr en de es nl)

config :claper, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, mailers: 20],
  repo: Claper.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}
  ]

config :dart_sass,
  version: "1.61.0",
  default: [
    args: ~w(css/custom.scss ../priv/static/assets/custom.css),
    cd: Path.expand("../assets", __DIR__)
  ]

config :tailwind,
  version: "4.1.10",
  default: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ],
  admin: [
    args: ~w(
      --input=assets/css/admin.css
      --output=priv/static/assets/admin.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.5",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :porcelain, driver: Porcelain.Driver.Basic

config :claper, :storage_dir, System.get_env("PRESENTATION_STORAGE_DIR", "priv/static")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
