defmodule ClaperWeb.Plugs.LtiEnabled do
  @moduledoc "Blocks LTI endpoints while the integration is globally disabled."
  import Plug.Conn

  def init(options), do: options

  def call(conn, _options) do
    if Claper.Settings.lti_enabled?() do
      conn
    else
      conn
      |> send_resp(:not_found, "Not Found")
      |> halt()
    end
  end
end
