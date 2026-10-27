defmodule Claper.SecurityAuditTest do
  use Claper.DataCase

  import Claper.AccountsFixtures
  alias Claper.Audit.{Log, Security}

  test "repeated suspicious activity is attributed and bounded even across resources" do
    user = confirmed_user_fixture()

    metadata = %{
      resource_type: "form",
      resource_id: 12,
      reason: "validation_rejected",
      body: "private answer",
      token: "secret"
    }

    for _ <- 1..2, do: Security.record(user, "security.suspicious_submission", metadata)
    assert logs(user) == []

    for id <- 12..40 do
      Security.record(user, "security.suspicious_submission", %{metadata | resource_id: id})
    end

    assert [log] = logs(user)
    assert log.resource_type == "form"
    assert log.resource_id == 12
    assert log.metadata["reason"] == "validation_rejected"
    assert log.metadata["observed_count"] == 3
    refute Map.has_key?(log.metadata, "body")
    refute Map.has_key?(log.metadata, "token")
  end

  test "anonymous actors are correlated without storing their cookie identifier" do
    identity = "private-attendee-#{System.unique_integer([:positive])}"
    fingerprint = Security.fingerprint(identity)

    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, attendee_identifier: identity, security_audit_ip: "192.0.2.10"}
    }

    for _ <- 1..3, do: ClaperWeb.SecurityAudit.observe(socket, "quiz", 17, "invalid_options")

    log =
      Repo.one!(
        from l in Log, where: fragment("?->>'attendee_fingerprint' = ?", l.metadata, ^fingerprint)
      )

    assert log.user_id == nil
    assert log.metadata["ip_address"] == "192.0.2.10"
    assert log.metadata["attendee_fingerprint"] != identity
    refute Jason.encode!(log.metadata) =~ identity
  end

  test "concurrent detections write only one audit record" do
    user = confirmed_user_fixture()

    1..12
    |> Task.async_stream(fn _ ->
      Security.record(user, "security.suspicious_submission", %{
        resource_type: "poll",
        reason: "already_voted"
      })
    end)
    |> Stream.run()

    assert [_] = logs(user)
  end

  defp logs(user), do: Repo.all(from l in Log, where: l.user_id == ^user.id)
end
