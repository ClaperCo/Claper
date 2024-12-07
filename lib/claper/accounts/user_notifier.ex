defmodule Claper.Accounts.UserNotifier do
  # import Swoosh.Email

  alias Claper.Mailer

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
    email = ClaperWeb.Notifiers.UserNotifier.magic(email, url)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_welcome(email) do
    email = ClaperWeb.Notifiers.UserNotifier.welcome(email)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    email = ClaperWeb.Notifiers.UserNotifier.confirm(user, url)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    email = ClaperWeb.Notifiers.UserNotifier.reset(user, url)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    email = ClaperWeb.Notifiers.UserNotifier.update_email(user, url)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
