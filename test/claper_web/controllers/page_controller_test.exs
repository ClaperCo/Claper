defmodule ClaperWeb.PageControllerTest do
  use ClaperWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "About"
  end
end
