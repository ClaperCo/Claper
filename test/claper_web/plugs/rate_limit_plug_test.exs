defmodule ClaperWeb.Plugs.RateLimitPlugTest do
  use ClaperWeb.ConnCase, async: true

  import Claper.AccountsFixtures
  alias Claper.Audit.Log
  alias ClaperWeb.Plugs.RateLimitPlug

  test "rate denials retain 429 and create one safe attributed audit entry", %{conn: conn} do
    user = confirmed_user_fixture()

    options =
      RateLimitPlug.init(max_requests: 1, interval_ms: 60_000, prefix: "test-auth-#{user.id}")

    conn =
      Plug.Test.conn(:post, "/users/log_in?password=not-for-audit")
      |> Map.put(:remote_ip, conn.remote_ip)
      |> assign(:current_user, user)

    assert RateLimitPlug.call(conn, options).state == :unset

    for _ <- 1..6 do
      denied = RateLimitPlug.call(conn, options)
      assert denied.status == 429
      assert denied.halted
      assert denied.resp_body == "Too Many Requests"
    end

    assert [log] = Claper.Repo.all(from l in Log, where: l.user_id == ^user.id)
    assert log.action == "security.rate_limit_exceeded"
    assert log.metadata["ip_address"] == conn.remote_ip |> :inet.ntoa() |> to_string()
    assert log.metadata["route"] == "/users/log_in"
    assert log.metadata["limit"] == 1
    assert log.metadata["retry_after_ms"] > 0
    refute Jason.encode!(log.metadata) =~ "not-for-audit"
  end
end
