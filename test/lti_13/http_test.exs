defmodule Lti13.HTTPTest do
  use Claper.DataCase

  alias Lti13.HTTP

  setup do
    {:ok, _} = Claper.Settings.set("lti_enabled", "true")
    previous = Application.fetch_env(:claper, :lti_http_resolver)

    on_exit(fn ->
      case previous do
        {:ok, resolver} -> Application.put_env(:claper, :lti_http_resolver, resolver)
        :error -> Application.delete_env(:claper, :lti_http_resolver)
      end
    end)

    :ok
  end

  test "disabling LTI stops all outbound methods before DNS resolution" do
    {:ok, _} = Claper.Settings.set("lti_enabled", "false")

    Application.put_env(:claper, :lti_http_resolver, fn _, _, _ ->
      flunk("DNS requested while disabled")
    end)

    Req.Test.stub(HTTP, fn _ -> flunk("network requested while disabled") end)

    assert {:error, :lti_disabled} = HTTP.get("https://lms.example/jwks")
    assert {:error, :lti_disabled} = HTTP.post("https://lms.example/scores")
    assert {:error, :lti_disabled} = HTTP.put("https://lms.example/line-items")
    assert {:error, :lti_disabled} = HTTP.validate_url("https://lms.example/registration")
  end

  test "refuses non-public destinations and ambiguous URL syntax without contacting them" do
    Req.Test.stub(HTTP, fn _conn -> flunk("unsafe network request") end)

    for url <- [
          "http://93.184.216.34/",
          "https://user:password@93.184.216.34/",
          "https://93.184.216.34/#fragment",
          "file:///etc/passwd",
          "https://127.0.0.1/",
          "https://0.0.0.0/",
          "https://10.0.0.1/",
          "https://100.100.100.200/",
          "https://169.254.169.254/",
          "https://172.16.0.1/",
          "https://192.168.1.1/",
          "https://198.18.0.1/",
          "https://224.0.0.1/",
          "https://255.255.255.255/",
          "https://[::]/",
          "https://[::1]/",
          "https://[::ffff:127.0.0.1]/",
          "https://[64:ff9b::7f00:1]/",
          "https://[fc00::1]/",
          "https://[fe80::1]/",
          "https://[2002:7f00:1::]/",
          "https://[2001:db8::1]/"
        ] do
      assert {:error, :unsafe_lti_url} = HTTP.get(url), url
    end
  end

  test "rejects a hostname if any DNS answer is internal" do
    Application.put_env(:claper, :lti_http_resolver, fn
      ~c"lms.example", :inet, _timeout -> {:ok, [{93, 184, 216, 34}]}
      ~c"lms.example", :inet6, _timeout -> {:ok, [{0, 0, 0, 0, 0, 0, 0, 1}]}
    end)

    Req.Test.stub(HTTP, fn _conn -> flunk("mixed DNS answers must be rejected") end)

    assert {:error, :unsafe_lti_url} = HTTP.get("https://lms.example/jwks")
  end

  test "pins the checked DNS address while preserving the platform Host header" do
    Application.put_env(:claper, :lti_http_resolver, fn
      ~c"lms.example", :inet, _timeout ->
        # A second resolution would return a private address.
        if Process.get(:dns_resolved) do
          {:ok, [{127, 0, 0, 1}]}
        else
          Process.put(:dns_resolved, true)
          {:ok, [{93, 184, 216, 34}]}
        end

      ~c"lms.example", :inet6, _timeout ->
        {:error, :nxdomain}
    end)

    Req.Test.stub(HTTP, fn conn ->
      assert conn.host == "93.184.216.34"
      assert Plug.Conn.get_req_header(conn, "host") == ["lms.example"]
      Req.Test.json(conn, %{"keys" => []})
    end)

    assert {:ok, %Req.Response{status: 200, body: %{"keys" => []}}} =
             HTTP.get("https://lms.example/jwks")
  end

  test "refuses unresolved destinations rather than delegating DNS to the HTTP client" do
    Application.put_env(:claper, :lti_http_resolver, fn _host, _family, _timeout ->
      {:error, :timeout}
    end)

    Req.Test.stub(HTTP, fn _conn -> flunk("unresolved network request") end)
    assert {:error, :unsafe_lti_url} = HTTP.get("https://lms.example/jwks")
  end

  test "does not follow redirects or forward a bearer token to their target" do
    Req.Test.stub(HTTP, fn
      %{request_path: "/jwks"} = conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "https://127.0.0.1/stolen")
        |> Plug.Conn.send_resp(307, "")

      _conn ->
        flunk("redirect destination contacted")
    end)

    assert {:ok, %Req.Response{status: 307}} =
             HTTP.get("https://93.184.216.34/jwks", headers: [{"authorization", "Bearer token"}])
  end
end
