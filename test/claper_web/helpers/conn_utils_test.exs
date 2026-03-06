defmodule ClaperWeb.Helpers.ConnUtilsTest do
  use ClaperWeb.ConnCase, async: true

  alias ClaperWeb.Helpers.ConnUtils

  describe "get_client_ip/1" do
    test "returns the remote_ip from the connection as a string" do
      conn = build_conn() |> Map.put(:remote_ip, {93, 184, 216, 34})
      assert ConnUtils.get_client_ip(conn) == "93.184.216.34"
    end

    test "handles IPv6 addresses" do
      conn = build_conn() |> Map.put(:remote_ip, {8193, 3512, 0, 0, 0, 0, 0, 1})
      assert ConnUtils.get_client_ip(conn) == "2001:db8::1"
    end
  end

  describe "get_user_agent/1" do
    test "returns the user agent header when present" do
      conn = build_conn() |> put_req_header("user-agent", "Mozilla/5.0")
      assert ConnUtils.get_user_agent(conn) == "Mozilla/5.0"
    end

    test "returns nil when no user agent header is present" do
      conn = build_conn()
      assert ConnUtils.get_user_agent(conn) == nil
    end
  end
end
