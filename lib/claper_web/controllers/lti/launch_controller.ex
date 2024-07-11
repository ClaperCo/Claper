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
        conn =
          conn
          |> put_session(:resource_id, resource_id)
          |> put_session(:user_id, user_id)
          |> set_user_return_to(resource, lti_user)

        UserAuth.log_in_user(conn, lti_user.user)

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

  defp set_user_return_to(conn, resource, lti_user) do
    if resource.event.user_id == lti_user.user_id do
      conn |> put_session(:user_return_to, ~p"/events")
    else
      conn |> put_session(:user_return_to, ~p"/e/#{resource.event.code}")
    end
  end
end
