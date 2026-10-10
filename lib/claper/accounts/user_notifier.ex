defmodule Claper.Accounts.UserNotifier do
  # import Swoosh.Email

  # Delivers the email using the application mailer.
  # defp deliver(recipient, subject, body) do
  #   from_name = Application.get_env(:claper, :mail)[:from_name]
  #   from_email = Application.get_env(:claper, :mail)[:from]

  #   email =
  #     new()
  #     |> to(recipient)
  #     |> from({from_name, from_email})
  #     |> subject(subject)
  #     |> text_body(body)

  #   with {:ok, _metadata} <- Mailer.deliver(email) do
  #     {:ok, email}
  #   end
  # end

  def deliver_magic_link(email, url) do
    Claper.Workers.Mailers.new_magic_link(email, url, email_locale(email)) |> Oban.insert()

    {:ok, :enqueued}
  end

  def deliver_welcome(email) do
    Claper.Workers.Mailers.new_welcome(email, request_locale()) |> Oban.insert()

    {:ok, :enqueued}
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    Claper.Workers.Mailers.new_confirmation(user.id, url, user_locale(user)) |> Oban.insert()

    {:ok, :enqueued}
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    Claper.Workers.Mailers.new_reset_password(user.id, url, user_locale(user)) |> Oban.insert()

    {:ok, :enqueued}
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    Claper.Workers.Mailers.new_update_email(user.email, url, user_locale(user)) |> Oban.insert()

    {:ok, :enqueued}
  end

  defp email_locale(email) do
    case Claper.Accounts.get_user_by_email(email) do
      nil -> request_locale()
      user -> user_locale(user)
    end
  end

  defp user_locale(user), do: user.locale || request_locale()

  defp request_locale, do: Gettext.get_locale(ClaperWeb.Gettext)
end
