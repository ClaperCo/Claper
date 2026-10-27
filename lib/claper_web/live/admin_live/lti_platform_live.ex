defmodule ClaperWeb.AdminLive.LtiPlatformLive do
  use ClaperWeb, :admin_live_view

  import ClaperWeb.AdminLive.DetailComponents

  alias Lti13.Registrations

  on_mount(ClaperWeb.UserLiveAuth)

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    if admin?(socket) do
      {:ok,
       socket
       |> assign(:page_title, gettext("LTI Platforms"))
       |> assign(:registrations, Registrations.list_registrations())}
    else
      {:ok, redirect(socket, to: ~p"/")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("approve", %{"id" => id}, socket) do
    update_registration(socket, id, &Registrations.approve_registration/2)
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    update_registration(socket, id, &Registrations.revoke_registration/2)
  end

  # Admin role is re-checked in the context against the database, not the session.
  defp update_registration(socket, id, fun) do
    with {int_id, ""} <- Integer.parse(to_string(id)),
         %Lti13.Registrations.Registration{} = registration <-
           Claper.Repo.get(Lti13.Registrations.Registration, int_id),
         {:ok, _registration} <- fun.(registration, socket.assigns.current_user) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("LTI platform updated."))
       |> assign(:registrations, Registrations.list_registrations())}
    else
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Unable to update LTI platform."))}
    end
  end

  defp admin?(socket) do
    case socket.assigns[:current_user] do
      %Claper.Accounts.User{id: id} ->
        case Claper.Accounts.get_user(id) do
          nil -> false
          user -> Claper.Accounts.user_has_role?(user, "admin")
        end

      _ ->
        false
    end
  end
end
