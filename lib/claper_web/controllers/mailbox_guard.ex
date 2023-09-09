defmodule ClaperWeb.MailboxGuard do
  import Plug.Conn
  import Phoenix.Controller

  def init(default), do: default

  def call(conn, _params \\ %{}) do
    mailbox_username = Application.get_env(:claper, ClaperWeb.MailboxGuard) |> Keyword.get(:username)
    mailbox_password = Application.get_env(:claper, ClaperWeb.MailboxGuard) |> Keyword.get(:password)
    mailbox_enabled = Application.get_env(:claper, ClaperWeb.MailboxGuard) |> Keyword.get(:enabled)

    IO.puts mailbox_enabled

    if mailbox_enabled do
      if mailbox_username && mailbox_password do
        Plug.BasicAuth.basic_auth(conn, username: mailbox_username, password: mailbox_password)
      else
        conn
      end
    else
      conn |> redirect(to: "/") |> halt()
    end
  end
end
