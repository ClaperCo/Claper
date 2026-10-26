defmodule ClaperWeb.PageControllerTest do
  use ClaperWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "About"
  end

  test "join pages cannot be framed by other origins", %{conn: conn} do
    for path <- ["/", "/join"] do
      conn = get(conn, path)
      assert get_resp_header(conn, "x-frame-options") == ["SAMEORIGIN"]
    end
  end
end
