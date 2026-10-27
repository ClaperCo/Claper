defmodule ClaperWeb.Lti.LaunchController do
  alias ClaperWeb.UserAuth
  use ClaperWeb, :controller

  def login(conn, params) do
    case Lti13.Tool.OidcLogin.oidc_login_redirect_url(params) do
      {:ok, state, redirect_url} ->
        conn
        |> put_session("state", state)
        |> redirect(external: redirect_url)

      {:error, %{reason: :invalid_registration, msg: msg, issuer: _issuer, client_id: _client_id}} ->
        render(conn, "error.html", msg: msg)

      {:error, %{reason: _reason, msg: msg}} ->
        render(conn, "error.html", msg: msg)
    end
  end

  def launch(conn, params) do
    session_state = Plug.Conn.get_session(conn, "state")
    conn = delete_session(conn, "state")

    case Lti13.Tool.LaunchValidation.validate(params, session_state) do
      {:ok,
       %{
         lti_user: lti_user,
         claims: %{
           "https://purl.imsglobal.org/spec/lti/claim/context" => %{
             "label" => _course_label,
             "title" => _course_title
           },
           "https://purl.imsglobal.org/spec/lti/claim/resource_link" => %{
             "title" => _resource_title,
             "id" => resource_id
           },
           "sub" => user_id
         },
         resource: resource
       }} ->
        log_in_or_confirm(conn, lti_user, resource_id, user_id, return_path(resource, lti_user))

      {:error, %{reason: :invalid_registration, msg: msg, issuer: _issuer, client_id: _client_id}} ->
        render(conn, "error.html", msg: msg)

      {:error,
       %{
         reason: :invalid_deployment,
         msg: msg,
         registration_id: _registration_id,
         deployment_id: _deployment_id
       }} ->
        render(conn, "error.html", msg: msg)

      {:error, %{reason: _reason, msg: msg}} ->
        render(conn, "error.html", msg: msg)
    end
  end

  @pending_key "lti_pending_switch"
  @pending_ttl_seconds 300

  @doc """
  Shows the account switch confirmation. Served from the CSRF-protected browser
  pipeline so the rendered form token is backed by the session.
  """
  def show_confirm(conn, _params) do
    with %{"token" => token} = pending <- get_session(conn, @pending_key),
         true <- pending["expires_at"] > System.system_time(:second),
         %Claper.Accounts.User{} = current <- conn.assigns[:current_user],
         %Claper.Accounts.User{} = target <- Claper.Accounts.get_user(pending["local_user_id"]) do
      render(conn, "confirm.html",
        token: token,
        current_email: current.email,
        lti_email: target.email
      )
    else
      _ -> invalid_switch(conn)
    end
  end

  @doc """
  Completes a pending account switch after the user explicitly confirms it
  from a CSRF-protected same-site form.
  """
  def confirm(conn, %{"token" => token}) when is_binary(token) do
    pending = get_session(conn, @pending_key)
    conn = delete_session(conn, @pending_key)

    with %{"token" => expected} <- pending,
         true <- Plug.Crypto.secure_compare(expected, token),
         true <- pending["expires_at"] > System.system_time(:second),
         %Lti13.Users.User{} = mapping <- authorized_mapping(pending["lti_user_id"]),
         true <- mapping.user_id == pending["local_user_id"],
         %Claper.Accounts.User{} = user <- Claper.Accounts.get_user(mapping.user_id) do
      conn
      |> put_session(:resource_id, pending["resource_id"])
      |> put_session(:user_id, pending["sub"])
      |> put_session(:user_return_to, pending["return_to"])
      |> UserAuth.log_in_user(user)
    else
      _ -> invalid_switch(conn)
    end
  end

  def confirm(conn, _params), do: conn |> delete_session(@pending_key) |> invalid_switch()

  @doc "Discards a pending account switch and keeps the current session."
  def cancel(conn, _params) do
    conn
    |> delete_session(@pending_key)
    |> redirect(to: ~p"/events")
  end

  # A launch must never silently replace an existing browser session with a
  # different account (login CSRF): require explicit same-site confirmation.
  defp log_in_or_confirm(conn, lti_user, resource_id, sub, return_to) do
    case conn.assigns[:current_user] do
      %Claper.Accounts.User{id: id} when id != lti_user.user_id ->
        pending = %{
          "token" => Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
          "lti_user_id" => lti_user.id,
          "local_user_id" => lti_user.user_id,
          "resource_id" => resource_id,
          "sub" => sub,
          "return_to" => return_to,
          "expires_at" => System.system_time(:second) + @pending_ttl_seconds
        }

        conn
        |> put_session(@pending_key, pending)
        |> redirect(to: ~p"/lti/launch/confirm")

      _ ->
        conn
        |> put_session(:resource_id, resource_id)
        |> put_session(:user_id, sub)
        |> put_session(:user_return_to, return_to)
        |> UserAuth.log_in_user(lti_user.user)
    end
  end

  defp invalid_switch(conn) do
    conn
    |> put_status(:bad_request)
    |> render("error.html", msg: gettext("This account switch request is invalid or expired."))
  end

  defp authorized_mapping(id) when is_integer(id) do
    case Claper.Repo.get(Lti13.Users.User, id) do
      %Lti13.Users.User{provisioned_at: nil, authorized_at: nil} -> nil
      mapping -> mapping
    end
  end

  defp authorized_mapping(_), do: nil

  defp return_path(resource, lti_user) do
    if resource.event.user_id == lti_user.user_id,
      do: ~p"/events",
      else: ~p"/e/#{resource.event.code}"
  end
end
