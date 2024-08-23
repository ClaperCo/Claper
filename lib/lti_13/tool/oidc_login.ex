defmodule Lti13.Tool.OidcLogin do
  alias Lti13.Registrations

  def oidc_login_redirect_url(params) do
    with {:ok, _issuer, login_hint, registration} <- validate_oidc_login(params) do
      # craft OIDC auth response

      # create unique state. Be sure to add this state to conn
      #
      # ## Example:
      # conn = conn
      #   |> put_session("state", state)
      state = UUID.uuid4()

      query_params = %{
        "scope" => "openid",
        "response_type" => "id_token",
        "response_mode" => "form_post",
        "prompt" => "none",
        "client_id" => params["client_id"],
        "redirect_uri" => params["target_link_uri"],
        "state" => state,
        "nonce" => UUID.uuid4(),
        "login_hint" => login_hint
      }

      # pass back LTI message hint if given
      query_params =
        case params["lti_message_hint"] do
          nil -> query_params
          lti_message_hint -> Map.put_new(query_params, "lti_message_hint", lti_message_hint)
        end

      redirect_url = registration.auth_login_url <> "?" <> URI.encode_query(query_params)

      {:ok, state, redirect_url}
    end
  end

  defp validate_oidc_login(params) do
    with {:ok, issuer} <- validate_issuer(params),
         {:ok, login_hint} <- validate_login_hint(params),
         {:ok, registration} <- validate_registration(params) do
      {:ok, issuer, login_hint, registration}
    end
  end

  defp validate_issuer(params) do
    case params["iss"] do
      nil -> {:error, %{reason: :missing_issuer, msg: "Request does not have an issuer (iss)"}}
      issuer -> {:ok, issuer}
    end
  end

  defp validate_login_hint(params) do
    case params["login_hint"] do
      nil ->
        {:error,
         %{reason: :missing_login_hint, msg: "Request does not have a login hint (login_hint)"}}

      login_hint ->
        {:ok, login_hint}
    end
  end

  defp validate_registration(params) do
    issuer = params["iss"]
    client_id = params["client_id"]
    lti_deployment_id = params["lti_deployment_id"]

    case Registrations.get_registration_by_issuer_client_id(issuer, client_id) do
      nil ->
        {:error,
         %{
           reason: :invalid_registration,
           msg: "Registration with issuer \"#{issuer}\" and client id \"#{client_id}\" not found",
           issuer: issuer,
           client_id: client_id,
           lti_deployment_id: lti_deployment_id
         }}

      registration ->
        {:ok, registration}
    end
  end
end
