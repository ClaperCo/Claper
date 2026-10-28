import Config

# Configure your database
#
# Tests use this dedicated database, not DATABASE_URL from the shell or .env.
# runtime.exs leaves these repository settings unchanged in the test environment.
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :claper, Claper.Repo,
  username: "claper",
  password: "claper",
  database: "claper_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :claper, ClaperWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "YnJKcv692Yso3lHGqaJ6kJxKBDh0BUL+mJhguLm5rzoJ+xCEuN7MdrguMSnHKoz4",
  server: false

# In test we don't send emails.
config :claper, Claper.Mailer, adapter: Swoosh.Adapters.Test

config :claper, Oban, testing: :inline

config :claper, :lti_http_req, plug: {Req.Test, Lti13.HTTP}

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
