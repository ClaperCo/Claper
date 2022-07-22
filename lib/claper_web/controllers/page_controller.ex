defmodule ClaperWeb.PageController do
  use ClaperWeb, :controller

  def index(conn, _params) do
    conn
    |> render("index.html")
  end

  def tos(conn, _params) do
    conn
    |> render("tos.html")
  end

  def privacy(conn, _params) do
    conn
    |> render("privacy.html")
  end
end
