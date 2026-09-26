defmodule ClaperWeb.Plugs.CSRFProtection do
  @moduledoc """
  Renders the CSRF error page when a form is submitted with a missing or stale
  token.

  `Plug.CSRFProtection` raises `Plug.CSRFProtection.InvalidCSRFTokenError`, which
  carries `plug_status: 403`. Phoenix catches it in its error handler, so the
  visitor gets the bare "Forbidden" body that `ClaperWeb.ErrorView` falls back to
  when there is no matching template, and the exception is reported to Sentry. In
  practice this happens when a form is posted from a page that was cached,
  bookmarked or left open until the session cookie was gone, which is what makes
  the login form the most affected one.

  This plug does what `plug(:protect_from_forgery)` did and turns that single
  exception into the existing `error/csrf_error.html` page with a 403, so the
  visitor is told to reload the page and sign in again. Every other exception is
  passed through untouched.

  It runs at the end of the browser pipeline so that the response still carries the
  session, the secure headers and the locale set by the plugs before it.
  """

  @behaviour Plug

  import Plug.Conn

  import Phoenix.Controller, only: [put_view: 2, render: 3]

  @impl true
  def init(opts), do: Plug.CSRFProtection.init(opts)

  @impl true
  def call(conn, opts) do
    Plug.CSRFProtection.call(conn, opts)
  rescue
    Plug.CSRFProtection.InvalidCSRFTokenError ->
      conn
      |> put_status(:forbidden)
      |> put_view(ClaperWeb.ErrorView)
      |> render("csrf_error.html", %{error: nil})
      |> halt()
  end
end
