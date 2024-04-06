defmodule ClaperWeb.Plugs.Iframe do
  import Plug.Conn
  def init(_), do: %{}

  def call(conn, _opts) do
    conn
    |> put_resp_header(
      "x-frame-options",
      "ALLOWALL"
    )
  end
end
