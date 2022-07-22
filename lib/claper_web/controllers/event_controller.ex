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

  def slide_generate(conn, %{"uuid" => uuid, "qr" => qr} = _opts) do
    with event <- Claper.Events.get_event!(uuid) do
      "data:image/png;base64," <> raw = qr
      {:ok, data} = Base.decode64(raw)
      dir = System.tmp_dir!()
      tmp_file = Path.join(dir, "qr-#{uuid}.png")
      File.write!(tmp_file, data, [:binary])

      code = String.upcase(event.code)

      {output, 0} =
        System.cmd("convert", [
          "-size",
          "1920x1080",
          "xc:black",
          "-fill",
          "white",
          "-font",
          "Roboto",
          "-pointsize",
          "45",
          "-gravity",
          "north",
          "-annotate",
          "+0+100",
          "Scannez pour interagir en temps-réel",
          "-gravity",
          "center",
          "-annotate",
          "+0+200",
          "Ou allez sur Claper.co et utilisez le code:",
          "-pointsize",
          "65",
          "-gravity",
          "center",
          "-annotate",
          "+0+350",
          "##{code}",
          tmp_file,
          "-gravity",
          "north",
          "-geometry",
          "+0+230",
          "-composite",
          "jpg:-"
        ])

      conn
      |> put_resp_content_type("image/png")
      |> send_resp(200, output)
    end
  end
end
