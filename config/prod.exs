import Config

config :claper, ClaperWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# Do not print debug messages in production
config :logger, level: :info
