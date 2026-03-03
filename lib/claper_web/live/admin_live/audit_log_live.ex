defmodule ClaperWeb.AdminLive.AuditLogLive do
  use ClaperWeb, :live_view

  alias Claper.Audit

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    {logs, meta} = Audit.list_logs(params)

    socket
    |> assign(:page_title, gettext("Audit Logs"))
    |> assign(:logs, logs)
    |> assign(:meta, meta)
    |> assign(:form, Phoenix.Component.to_form(meta))
    |> assign_new(:action_types, &Audit.list_action_types/0)
    |> assign_new(:fields, fn %{action_types: action_types} ->
      [
        user_email: [
          label: nil,
          placeholder: gettext("Search by user email"),
          type: "text",
          op: :ilike_or
        ],
        action: [
          label: nil,
          prompt: gettext("All actions"),
          field: :action,
          type: "select",
          options: action_types
        ]
      ]
    end)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Audit Log Details"))
    |> assign(:log, Audit.get_log!(id))
  end

  @impl Phoenix.LiveView
  def handle_event("filter-logs", unsigned_params, socket) do
    flop = Flop.validate!(unsigned_params, for: Audit.Log, replace_invalid_params: true)
    to = Flop.Phoenix.build_path(~p"/admin/audit_logs", flop)

    {:noreply, push_patch(socket, to: to)}
  end

  defp format_metadata(nil), do: "—"
  defp format_metadata(metadata) when map_size(metadata) == 0, do: "—"

  defp format_metadata(metadata) do
    Enum.map_join(metadata, ", ", fn {k, v} -> "#{k}: #{v}" end)
  end

  defp format_timestamp(%NaiveDateTime{} = timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S\u00A0UTC")
  end

  defp format_timestamp(timestamp), do: inspect(timestamp)
end
