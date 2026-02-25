defmodule ClaperWeb.Plugs.RateLimitPlug do
  @moduledoc """
  Plug for rate limiting requests based on client IP address.

  ## Usage

      plug ClaperWeb.Plugs.RateLimitPlug, max_requests: 10, interval_ms: 60_000, prefix: "login"
  """
  import Plug.Conn

  def init(opts) do
    %{
      max_requests: Keyword.get(opts, :max_requests, 10),
      interval_ms: Keyword.get(opts, :interval_ms, 60_000),
      prefix: Keyword.get(opts, :prefix, "default")
    }
  end

  def call(conn, %{max_requests: max_requests, interval_ms: interval_ms, prefix: prefix}) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    key = "#{prefix}:#{ip}"

    case Claper.RateLimit.hit(key, interval_ms, max_requests) do
      {:allow, _count} ->
        conn

      {:deny, _retry_after} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(429, "Too Many Requests")
        |> halt()
    end
  end
end
