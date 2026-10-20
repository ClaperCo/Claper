defmodule ClaperWeb.EventController do
  use ClaperWeb, :controller

  def attendee_identifier(conn, _opts) do
    conn |> set_token()
  end

  defp set_token(conn) do
    if is_nil(get_session(conn, :attendee_identifier)) do
      token = Base.url_encode64(:crypto.strong_rand_bytes(8))

      conn
      |> put_session(:attendee_identifier, token)
    else
      conn
    end
  end
end
