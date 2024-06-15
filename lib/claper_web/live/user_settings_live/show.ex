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

    preferences_changeset =
      Accounts.User.preferences_changeset(
        socket.assigns.current_user,
        set_locale(socket.assigns.current_user)
      )

    {:ok,
     socket
     |> assign(:email_changeset, email_changeset)
     |> assign(:password_changeset, password_changeset)
     |> assign(:preferences_changeset, preferences_changeset)}
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
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("A link to confirm your email change has been sent to the new address.")
         )
         |> push_navigate(to: ~p"/users/settings")}

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
         |> push_navigate(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("save", %{"action" => "update_preferences"} = params, socket) do
    locale = params["user"]["locale"]
    available_locales = Gettext.known_locales(ClaperWeb.Gettext)

    if Enum.member?(available_locales, locale) do
      case Accounts.update_user_preferences(socket.assigns.current_user, params["user"]) do
        {:ok, _applied_user} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             gettext("Your preferences have been updated.")
           )
           |> redirect(to: ~p"/users/settings")}

        {:error, changeset} ->
          {:noreply, assign(socket, :preferences_changeset, changeset)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_account", _params, %{assigns: %{current_user: user}} = socket) do
    Accounts.delete(user)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Your account has been deleted."))
     |> redirect(to: ~p"/users/log_in")}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  defp set_locale(user) when is_nil(user.locale) do
    %{"locale" => "en"}
  end

  defp set_locale(user) do
    %{"locale" => user.locale}
  end
end
