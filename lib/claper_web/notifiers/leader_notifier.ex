defmodule ClaperWeb.Notifiers.LeaderNotifier do
  use Phoenix.Swoosh, view: ClaperWeb.LeaderNotifierView, layout: {ClaperWeb.LayoutView, :email}
  use Gettext, backend: ClaperWeb.Gettext

  def event_invitation(event_name, email, url) do
    new()
    |> to(email)
    |> from(
      {Application.get_env(:claper, :mail) |> Keyword.get(:from_name),
       Application.get_env(:claper, :mail) |> Keyword.get(:from)}
    )
    |> subject(gettext("You have been invited to manage an event"))
    |> render_body("invitation.html", %{event_name: event_name, leader_email: email, url: url})
  end
end
