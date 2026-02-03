defmodule ClaperWeb.Helpers.ConnUtils do
  @moduledoc """
  Utility functions for extracting information from Plug.Conn.
  """

  @doc """
  Extracts the client IP address from the connection.

  Checks the `x-forwarded-for` header first (for proxied requests),
  falling back to the connection's remote_ip.
  """
  def get_client_ip(conn) do
    forwarded_for = Plug.Conn.get_req_header(conn, "x-forwarded-for")

    case forwarded_for do
      [ip | _] -> ip |> String.split(",") |> List.first() |> String.trim()
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
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
