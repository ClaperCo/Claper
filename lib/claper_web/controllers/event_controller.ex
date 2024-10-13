defmodule ClaperWeb.EventController do
  use ClaperWeb, :new_controller

  alias Claper.{Posts, Polls, Forms}
  alias ClaperWeb.Presence

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
          "Ou utilisez le code:",
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

  def vue(conn, %{"code" => code}) do
    event =
      Claper.Events.get_event_with_code(code,
        presentation_file: [:presentation_state],
        user: []
      )

    if is_nil(event) do
      conn
       |> put_flash(:error, gettext("Event doesn't exist"))
       |> redirect(to: "/")
    else
      init(
        conn,
        event,
        false
      )
    end
  end

  defp init(conn, _event, true) do
    conn
    |> put_flash(:error, gettext("You have been banned from this event"))
    |> redirect(to: "/")
  end

  defp init(conn, event, false) do

    # Claper.Events.Event.subscribe(event.uuid)
    # Claper.Presentations.subscribe(event.presentation_file.id)

    attendee_identifier = conn |> get_session(:attendee_identifier)

    post_changeset = Posts.Post.changeset(%Posts.Post{}, %{})

    # online = Presence.list("event:#{event.uuid}") |> Enum.count()
    # IO.inspect(online)

    conn
      |> assign(:post_changeset, post_changeset)
      |> assign(:selected_poll_opt, [])
      |> assign(:poll_opt_saved, false)
      |> assign(:event, event)
      |> assign(:state, event.presentation_file.presentation_state)
      |> assign(:nickname, "")
      |> render(:attendee, layout: false)
  end

  # defp check_if_banned(banned, %{assigns: %{current_user: current_user} = _assigns} = _conn)
  #      when is_map(current_user) do
  #   Enum.member?(banned, "#{current_user.id}")
  # end

  # defp check_if_banned(
  #        banned,
  #        %{assigns: %{attendee_identifier: attendee_identifier} = _assigns} = _conn
  #      ) do
  #   Enum.member?(banned, attendee_identifier)
  # end
end
