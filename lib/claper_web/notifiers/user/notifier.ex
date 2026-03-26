defmodule ClaperWeb.Notifiers.User.Notifier do
  use Gettext, backend: ClaperWeb.Gettext
  alias ClaperWeb.Notifiers.User.NotifierComponents
  import Swoosh.Email

  def magic(email, url) do
    magic_template = NotifierComponents.magic(%{url: url})

    new()
    |> to(email)
    |> from(
      {Application.get_env(:claper, :mail) |> Keyword.get(:from_name),
       Application.get_env(:claper, :mail) |> Keyword.get(:from)}
    )
    |> subject(gettext("Connect to Claper"))
    |> html_body(magic_template)
  end

  def welcome(email) do
    welcome_template = NotifierComponents.welcome(%{email: email})

    new()
    |> to(email)
    |> from(
      {Application.get_env(:claper, :mail) |> Keyword.get(:from_name),
       Application.get_env(:claper, :mail) |> Keyword.get(:from)}
    )
    |> subject(gettext("Next steps to boost your presentations"))
    |> html_body(welcome_template)
  end

  def update_email(new_email, url) do
    change_template = NotifierComponents.change(%{url: url})

    new()
    |> to(new_email)
    |> from(
      {Application.get_env(:claper, :mail) |> Keyword.get(:from_name),
       Application.get_env(:claper, :mail) |> Keyword.get(:from)}
    )
    |> subject(gettext("Update email instructions"))
    |> html_body(change_template)
  end

  def confirm(user, url) do
    confirm_template = NotifierComponents.confirm(%{user: user, url: url})

    new()
    |> to(user.email)
    |> from(
      {Application.get_env(:claper, :mail) |> Keyword.get(:from_name),
       Application.get_env(:claper, :mail) |> Keyword.get(:from)}
    )
    |> subject(gettext("Confirmation instructions"))
    |> html_body(confirm_template)
  end

  def reset(user, url) do
    reset_template = NotifierComponents.reset(%{user: user, url: url})

    new()
    |> to(user.email)
    |> from(
      {Application.get_env(:claper, :mail) |> Keyword.get(:from_name),
       Application.get_env(:claper, :mail) |> Keyword.get(:from)}
    )
    |> subject(gettext("Reset password instructions"))
    |> html_body(reset_template)
  end
end
