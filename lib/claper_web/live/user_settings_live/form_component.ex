defmodule ClaperWeb.UserSettingsLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Accounts

  @impl true
  def update(assigns, socket) do
    email_changeset = Accounts.User.email_changeset(%Accounts.User{}, %{})

    {:ok,
     socket
     |> assign(:email_changeset, email_changeset)
     |> assign(assigns)}
  end

  @impl true
  def handle_event("save", %{"action" => "update_email"} = params, socket) do
    %{"user" => user_params} = params

    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_update_email_instructions(
          applied_user,
          user.email,
          &Routes.user_settings_url(socket, :confirm_email, &1)
        )

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("A link to confirm your email change has been sent to the new address.")
         )
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end
end
