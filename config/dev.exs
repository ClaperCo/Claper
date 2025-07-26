import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to bundle .js and .css sources.
config :claper, ClaperWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  watchers: [
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]},
    tailwind_admin: {Tailwind, :install_and_run, [:admin, ~w(--watch)]},
    sass: {
      DartSass,
      :install_and_run,
      [:default, ~w(--embed-source-map --source-map-urls=absolute --watch)]
    }
  ]

# Watch static and templates for browser reloading.
config :claper, ClaperWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/[^uploads].*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/claper_web/(live|views)/.*(ex)$",
      ~r"lib/claper_web/templates/.*(eex)$",
      ~r"assets/.*\.(js|css)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
