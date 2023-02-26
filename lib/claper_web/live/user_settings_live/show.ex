defmodule ClaperWeb.UserSettingsLive.Show do
  use ClaperWeb, :live_view

  alias Claper.Accounts

  on_mount(ClaperWeb.UserLiveAuth)

  @impl true
  def mount(_params, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    email_changeset = Accounts.User.email_changeset(%Accounts.User{}, %{})
    password_changeset = Accounts.User.password_changeset(%Accounts.User{}, %{})

    {:ok,
     socket
     |> assign(:email_changeset, email_changeset)
     |> assign(:password_changeset, password_changeset)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit_email, _params) do
    socket
    |> assign(:page_title, gettext("Update your email"))
    |> assign(
      :page_description,
      gettext("Change the email address you want associated with your account.")
    )
  end

  defp apply_action(socket, :edit_password, _params) do
    socket
    |> assign(:page_title, gettext("Update your password"))
    |> assign(
      :page_description,
      gettext("Change the password used to access your account.")
    )
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, gettext("Settings"))
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
         |> push_redirect(to: Routes.user_settings_show_path(socket, :show))}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("save", %{"action" => "update_password"} = params, socket) do
    %{"user" => user_params} = params
    %{"current_password" => password} = user_params

    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, _applied_user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Your password has been updated.")
         )
         |> push_redirect(to: Routes.user_settings_show_path(socket, :show))}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end
end
