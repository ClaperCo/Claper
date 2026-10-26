defmodule ClaperWeb.SecurityAudit do
  @moduledoc "Collects trusted actor context without recording submitted content."
  alias Claper.Audit.Security

  def observe(socket, resource_type, resource_id, reason, threshold \\ 3) do
    assigns = socket.assigns
    event = assigns[:event]
    presentation_file = assigns[:presentation_file]

    Security.record(
      assigns[:current_user],
      "security.suspicious_submission",
      %{
        resource_type: resource_type,
        resource_id: resource_id,
        reason: reason,
        event_id:
          cond do
            is_map(event) -> event.id
            is_map(presentation_file) -> presentation_file.event_id
            true -> nil
          end,
        ip_address: assigns[:security_audit_ip],
        attendee_fingerprint: Security.fingerprint(assigns[:attendee_identifier])
      },
      threshold
    )
  end

  def peer_ip(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: address} -> address |> :inet.ntoa() |> to_string()
      _ -> nil
    end
  end
end
