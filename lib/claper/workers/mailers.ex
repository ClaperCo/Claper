defmodule Claper.Workers.Mailers do
  use Oban.Worker, queue: :mailers

  alias Claper.Mailer
  alias ClaperWeb.Notifiers.UserNotifier

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => type, "user_id" => user_id, "url" => url}})
      when type in ["confirm", "reset", "update_email"] do
    user = Claper.Accounts.get_user!(user_id)

    email =
      case type do
        "confirm" -> UserNotifier.confirm(user, url)
        "reset" -> UserNotifier.reset(user, url)
        "update_email" -> UserNotifier.update_email(user, url)
      end

    Mailer.deliver(email)
  end

  def perform(%Oban.Job{args: %{"type" => "magic", "email" => email, "url" => url}}) do
    email = UserNotifier.magic(email, url)
    Mailer.deliver(email)
  end

  def perform(%Oban.Job{args: %{"type" => "welcome", "email" => email}}) do
    email = UserNotifier.welcome(email)
    Mailer.deliver(email)
  end

  # Helper functions to create jobs
  def new_confirmation(user_id, url) do
    new(%{type: "confirm", user_id: user_id, url: url})
  end

  def new_reset_password(user_id, url) do
    new(%{type: "reset", user_id: user_id, url: url})
  end

  def new_update_email(user_id, url) do
    new(%{type: "update_email", user_id: user_id, url: url})
  end

  def new_magic_link(email, url) do
    new(%{type: "magic", email: email, url: url})
  end

  def new_welcome(email) do
    new(%{type: "welcome", email: email})
  end
end
