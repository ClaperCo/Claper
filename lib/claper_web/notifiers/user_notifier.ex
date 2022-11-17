defmodule ClaperWeb.Notifiers.UserNotifier do
  use Phoenix.Swoosh, view: ClaperWeb.UserNotifierView, layout: {ClaperWeb.LayoutView, :email}
  import ClaperWeb.Gettext

  def magic(email, url) do
    new()
    |> to(email)
    |> from(
      {System.get_env("MAIL_FROM_NAME", "Claper"),
       System.get_env("MAIL_FROM", "noreply@claper.co")}
    )
    |> subject(gettext("Connect to Claper"))
    |> render_body("magic.html", %{url: url})
  end

  def welcome(email) do
    new()
    |> to(email)
    |> from(
      {System.get_env("MAIL_FROM_NAME", "Claper"),
       System.get_env("MAIL_FROM", "noreply@claper.co")}
    )
    |> subject(gettext("Next steps to boost your presentations"))
    |> render_body("welcome.html", %{email: email})
  end

  def update_email(user, url) do
    new()
    |> to(user.email)
    |> from(
      {System.get_env("MAIL_FROM_NAME", "Claper"),
       System.get_env("MAIL_FROM", "noreply@claper.co")}
    )
    |> subject(gettext("Update email instructions"))
    |> render_body("change.html", %{user: user, url: url})
  end
end
