defmodule ClaperWeb.Helpers.ConnUtils do
  @moduledoc """
  Utility functions for extracting information from Plug.Conn.
  """

  @doc """
  Extracts the client IP address from the connection.

  The `RemoteIp` plug (configured in the endpoint) resolves the real client IP
  by inspecting the headers defined in `REMOTE_IP_HEADERS` and trusting only
  the proxies listed in `REMOTE_IP_PROXIES`, then rewrites `conn.remote_ip`
  before this is called.
  """
  def get_client_ip(conn) do
    conn.remote_ip |> :inet.ntoa() |> to_string()
  end

  @doc """
  Extracts the user agent string from the connection.

  Returns `nil` if no user agent header is present.
  """
  def get_user_agent(conn) do
    user_agent = Plug.Conn.get_req_header(conn, "user-agent")

    case user_agent do
      [ua | _] -> ua
      [] -> nil
    end
  end
end
