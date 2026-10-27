defmodule ClaperWeb.AdminLive.NavHook do
  @moduledoc """
  Assigns the current admin section as `:active_tab` on mount so the admin
  sidebar can highlight the active page.

  The sidebar lives in the `:admin_app` layout, which re-renders on every live
  navigation between admin LiveViews. Deriving the tab from `socket.view` keeps
  the highlight in sync without each LiveView having to set it explicitly.
  """
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:active_tab, active_tab(socket.view))
     |> assign(:lti_enabled, Claper.Settings.lti_enabled?())}
  end

  defp active_tab(ClaperWeb.AdminLive.DashboardLive), do: :dashboard
  defp active_tab(ClaperWeb.AdminLive.EventLive), do: :events
  defp active_tab(ClaperWeb.AdminLive.UserLive), do: :users
  defp active_tab(ClaperWeb.AdminLive.AuditLogLive), do: :audit_logs
  defp active_tab(ClaperWeb.AdminLive.OidcProviderLive), do: :oidc_providers
  defp active_tab(ClaperWeb.AdminLive.LtiPlatformLive), do: :lti_platforms
  defp active_tab(ClaperWeb.AdminLive.SettingsLive), do: :settings
  defp active_tab(_), do: nil
end
