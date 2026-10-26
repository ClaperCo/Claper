defmodule ClaperWeb.Lti.GlobalSettingTest do
  use ClaperWeb.ConnCase, async: true

  alias Claper.Settings

  test "disabled LTI blocks all public endpoints and can be re-enabled", %{conn: conn} do
    Settings.clear("lti_enabled")
    Req.Test.stub(Lti13.HTTP, fn _ -> flunk("disabled LTI contacted a platform") end)

    endpoints = [
      {:get, "/lti/register"},
      {:get, "/lti/register/continue"},
      {:post, "/lti/register"},
      {:get, "/lti/login"},
      {:post, "/lti/login"},
      {:post, "/lti/launch"},
      {:get, "/lti/launch/confirm"},
      {:post, "/lti/launch/confirm"},
      {:post, "/lti/launch/cancel"},
      {:get, "/.well-known/jwks.json"}
    ]

    for {method, path} <- endpoints do
      result = dispatch(conn, @endpoint, method, path, %{})
      assert response(result, 404) == "Not Found"
      assert get_resp_header(result, "set-cookie") == []
    end

    {:ok, _} = Settings.set("lti_enabled", "true")
    assert response(post(conn, "/lti/register", %{}), 401)

    {:ok, _} = Settings.set("lti_enabled", "false")
    assert response(post(conn, "/lti/register", %{}), 404) == "Not Found"
  end
end
