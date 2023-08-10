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
  url: [host: "localhost"],
  render_errors: [view: ClaperWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Claper.PubSub,
  live_view: [signing_salt: "DN0vwriJgVkHG0kn3hF5JKho/DE66onv"]

config :claper, ClaperWeb.Gettext,
  default_locale: "en",
  locales: ~w(fr en de)

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :claper, Claper.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

config :dart_sass,
  version: "1.58.0",
  default: [
    args: ~w(css/custom.scss ../priv/static/assets/custom.css),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.12.18",
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

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: {:system, "AWS_REGION"},
  normalize_path: false

config :claper,
  max_file_size: {:system, "MAX_FILE_SIZE_MB", "15"}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
