defmodule ClaperWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :claper

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options (case Mix.env() do
                      :dev ->
                        [
                          store: :cookie,
                          key: "_claper_key",
                          signing_salt: "Tg18Y2zU",
                          same_site: "None",
                          secure: true
                        ]

                      _ ->
                        [
                          store: :cookie,
                          key: "_claper_key",
                          signing_salt: "Tg18Y2zU"
                        ]
                    end)

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :claper,
    gzip: false,
    only: ClaperWeb.static_paths()

  plug Plug.Static,
    at: "/uploads",
    from: Path.join([Application.compile_env(:claper, :storage_dir), "uploads"]),
    gzip: false

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :claper
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug ClaperWeb.Router
end
