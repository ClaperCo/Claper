defmodule ClaperWeb.Lti.RegistrationControllerTest do
  use ClaperWeb.ConnCase

  import Lti13.JwksFixtures

  alias Claper.Repo
  alias Lti13.Deployments.Deployment
  alias Lti13.Registrations.Registration

  @stub Lti13.HTTP
  @openid_configuration "https://93.184.216.34/openid-configuration"
  @params %{"openid_configuration" => @openid_configuration, "registration_token" => "reg-token"}

  setup do
    {:ok, _} = Claper.Settings.set("lti_enabled", "true")
    :ok
  end

  defp platform_configuration do
    %{
      "issuer" => "https://93.184.216.34",
      "registration_endpoint" => "https://93.184.216.34/register",
      "jwks_uri" => "https://93.184.216.34/jwks",
      "authorization_endpoint" => "https://93.184.216.34/auth",
      "token_endpoint" => "https://93.184.216.34/token"
    }
  end

  defp stub_platform(deployment_id) do
    Req.Test.stub(@stub, fn
      %{request_path: "/openid-configuration"} = conn ->
        Req.Test.json(conn, platform_configuration())

      %{request_path: "/register"} = conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer reg-token"]

        Req.Test.json(conn, %{
          "client_id" => "client-123",
          "https://purl.imsglobal.org/spec/lti-tool-configuration" => %{
            "deployment_id" => deployment_id
          }
        })
    end)
  end

  test "Moodle's iframe receives only a safe link to top-level registration", %{conn: conn} do
    conn = get(conn, ~p"/lti/register", @params)
    html = html_response(conn, 200)
    assert get_resp_header(conn, "x-frame-options") == []
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
    document = Floki.parse_document!(html)
    assert Floki.find(document, "form") == []
    assert [link] = Floki.find(document, "#open-lti-registration")
    assert Floki.attribute(link, "target") == ["_blank"]
    assert Floki.attribute(link, "rel") == ["noopener noreferrer"]
    [destination] = Floki.attribute(link, "href")
    assert URI.parse(destination).path == "/lti/register/continue"
    assert URI.decode_query(URI.parse(destination).query) == @params
  end

  test "anonymous continuation preserves registration through local login", %{conn: conn} do
    conn = get(conn, ~p"/lti/register/continue", @params)
    assert redirected_to(conn) == ~p"/users/log_in"
    assert get_resp_header(conn, "x-frame-options") == ["SAMEORIGIN"]
    destination = URI.parse(get_session(conn, :user_return_to))
    assert destination.path == "/lti/register/continue"
    assert URI.decode_query(destination.query) == @params
  end

  test "registration credentials are redacted from request parameter logs", %{conn: conn} do
    previous_level = Logger.level()

    try do
      Logger.configure(level: :debug)

      logs =
        ExUnit.CaptureLog.capture_log([level: :debug], fn ->
          get(conn, ~p"/lti/register", @params)
        end)

      assert logs =~ "registration_token"
      assert logs =~ "[FILTERED]"
      refute logs =~ @params["registration_token"]
    after
      Logger.configure(level: previous_level)
    end
  end

  describe "POST /lti/register as anonymous user" do
    test "rejects anonymous users without contacting the platform", %{conn: conn} do
      Req.Test.stub(@stub, fn _conn -> flunk("unexpected outbound request") end)

      conn = post(conn, ~p"/lti/register", @params)

      assert html_response(conn, 401) =~ "You must log in to continue"
    end
  end

  describe "POST /lti/register" do
    setup :register_and_log_in_user

    test "registers the platform and its deployment", %{conn: conn, user: user} do
      jwk = jwk_fixture()
      stub_platform("1")

      conn = post(conn, ~p"/lti/register", @params)

      assert html_response(conn, 200) =~ "Registration completed"

      registration = Repo.get_by!(Registration, client_id: "client-123")
      assert registration.issuer == "https://93.184.216.34"
      assert registration.user_id == user.id
      assert registration.tool_jwk_id == jwk.id

      assert Repo.get_by!(Deployment, deployment_id: 1).registration_id == registration.id
    end

    test "registrations by non-administrators stay pending", %{conn: conn} do
      jwk_fixture()
      stub_platform("1")

      conn = post(conn, ~p"/lti/register", @params)

      html = html_response(conn, 200)
      assert html =~ "Registration completed"
      assert html =~ "An administrator of this Claper instance must approve this platform"

      registration = Repo.get_by!(Registration, client_id: "client-123")
      assert registration.approved_at == nil
      assert registration.approved_by_id == nil
      refute Lti13.Registrations.approved?(registration)
    end

    test "registrations by administrators are approved immediately", %{conn: conn, user: user} do
      unless Claper.Accounts.get_role_by_name("admin"),
        do: {:ok, _} = Claper.Accounts.create_role(%{name: "admin"})

      {:ok, _} = Claper.Accounts.assign_role(user, "admin")
      jwk_fixture()
      stub_platform("1")

      conn = post(conn, ~p"/lti/register", @params)

      html = html_response(conn, 200)
      refute html =~ "An administrator of this Claper instance must approve this platform"

      registration = Repo.get_by!(Registration, client_id: "client-123")
      assert registration.approved_at
      assert registration.approved_by_id == user.id
    end

    test "does not keep a registration when the deployment is invalid", %{conn: conn} do
      jwk_fixture()
      stub_platform("not-an-integer")

      conn = post(conn, ~p"/lti/register", @params)

      assert html_response(conn, 400) =~ "Registration with your platform failed"
      assert Repo.aggregate(Registration, :count) == 0
    end

    test "renders an error when the openid configuration is not JSON", %{conn: conn} do
      jwk_fixture()

      Req.Test.stub(@stub, fn conn ->
        Req.Test.html(conn, "This URL has no default content configured.")
      end)

      conn = post(conn, ~p"/lti/register", @params)

      assert html_response(conn, 400) =~ "Registration with your platform failed"
      assert Repo.aggregate(Registration, :count) == 0
    end

    test "renders an error when the platform rejects the registration", %{conn: conn} do
      jwk_fixture()

      Req.Test.stub(@stub, fn
        %{request_path: "/openid-configuration"} = conn ->
          Req.Test.json(conn, platform_configuration())

        %{request_path: "/register"} = conn ->
          conn |> Plug.Conn.put_status(403) |> Req.Test.json(%{"error" => "invalid token"})
      end)

      conn = post(conn, ~p"/lti/register", @params)

      assert html_response(conn, 400) =~ "Registration with your platform failed"
      assert Repo.aggregate(Registration, :count) == 0
    end

    test "renders an error for a non-HTTP openid configuration URL", %{conn: conn} do
      jwk_fixture()
      Req.Test.stub(@stub, fn _conn -> flunk("unexpected outbound request") end)

      conn = post(conn, ~p"/lti/register", %{@params | "openid_configuration" => "file:///etc"})

      assert html_response(conn, 400) =~ "Registration with your platform failed"
    end

    test "rejects internal and metadata destinations without any outbound request", %{conn: conn} do
      jwk_fixture()
      Req.Test.stub(@stub, fn _conn -> flunk("unexpected outbound request") end)

      for url <- [
            "https://127.0.0.1/admin",
            "https://169.254.169.254/latest/meta-data/",
            "https://[::1]/",
            "http://93.184.216.34/"
          ] do
        response = post(conn, ~p"/lti/register", %{@params | "openid_configuration" => url})
        assert html_response(response, 400) =~ "Registration with your platform failed"
      end
    end

    test "rejects private platform endpoints before sending the registration token", %{conn: conn} do
      jwk_fixture()

      Req.Test.stub(@stub, fn
        %{request_path: "/openid-configuration"} = conn ->
          Req.Test.json(conn, %{
            platform_configuration()
            | "registration_endpoint" => "https://127.0.0.1/admin"
          })

        _conn ->
          flunk("registration credentials must not be sent to an internal address")
      end)

      response = post(conn, ~p"/lti/register", @params)
      assert html_response(response, 400) =~ "Registration with your platform failed"
      assert Repo.aggregate(Registration, :count) == 0
    end

    test "does not follow discovery redirects", %{conn: conn} do
      jwk_fixture()

      Req.Test.stub(@stub, fn
        %{request_path: "/openid-configuration"} = conn ->
          conn
          |> Plug.Conn.put_resp_header("location", "https://127.0.0.1/private")
          |> Plug.Conn.send_resp(302, "")

        _conn ->
          flunk("redirect followed")
      end)

      response = post(conn, ~p"/lti/register", @params)
      assert html_response(response, 400) =~ "Registration with your platform failed"
    end

    test "requires a CSRF token even with an authenticated session", %{conn: conn} do
      Req.Test.stub(@stub, fn _conn -> flunk("unexpected outbound request") end)

      assert_error_sent 403, fn ->
        conn
        |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
        |> post(~p"/lti/register", @params)
      end
    end

    test "accepts a same-site form with its CSRF token", %{conn: conn} do
      jwk_fixture()
      stub_platform("1")

      form_conn = get(conn, ~p"/lti/register/continue", @params)
      assert get_resp_header(form_conn, "x-frame-options") == ["SAMEORIGIN"]
      assert get_resp_header(form_conn, "referrer-policy") == ["no-referrer"]

      token =
        form_conn
        |> html_response(200)
        |> Floki.parse_document!()
        |> Floki.attribute("input[name=_csrf_token]", "value")
        |> hd()

      response =
        form_conn
        |> recycle()
        |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
        |> post(~p"/lti/register", Map.put(@params, "_csrf_token", token))

      assert html_response(response, 200) =~ "Registration completed"
    end
  end
end
