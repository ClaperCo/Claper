defmodule ClaperWeb.Lti.RegistrationController do
  use ClaperWeb, :controller

  require Logger

  @tool_configuration_claim "https://purl.imsglobal.org/spec/lti-tool-configuration"

  def new(conn, %{"openid_configuration" => conf, "registration_token" => token}) do
    conn
    |> delete_resp_header("x-frame-options")
    |> put_resp_header(
      "content-security-policy",
      "frame-ancestors *; form-action 'none'; script-src 'none'; base-uri 'none'"
    )
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("cache-control", "no-store")
    |> put_root_layout(false)
    |> put_layout(false)
    |> render("start.html", conf: conf, token: token)
  end

  def new(conn, _params) do
    conn |> render(ClaperWeb.ErrorView, "404.html")
  end

  def continue(conn, %{"openid_configuration" => conf, "registration_token" => token}) do
    conn =
      conn
      |> put_resp_header("referrer-policy", "no-referrer")
      |> put_resp_header("cache-control", "no-store")

    if conn.assigns.current_user do
      render(conn, "new.html", conf: conf, token: token, current_user: conn.assigns.current_user)
    else
      conn
      |> put_session(:user_return_to, current_path(conn))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def continue(conn, _params) do
    conn |> put_status(:not_found) |> render(ClaperWeb.ErrorView, "404.html")
  end

  def create(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> render_error(gettext("You must log in to continue"))
  end

  def create(conn, %{"openid_configuration" => conf, "registration_token" => token})
      when is_binary(conf) and is_binary(token) do
    with %Lti13.Jwks.Jwk{} = jwk <- Lti13.Jwks.get_active_jwk(),
         {:ok, platform} <- fetch_platform_configuration(conf),
         {:ok, tool} <- register_tool(platform.registration_endpoint, token),
         {:ok, registration, _deployment} <-
           Lti13.Registrations.create_registration_with_deployment(
             %{
               issuer: platform.issuer,
               client_id: tool.client_id,
               key_set_url: platform.jwks_uri,
               auth_token_url: platform.token_endpoint,
               auth_login_url: platform.authorization_endpoint,
               auth_server: platform.issuer,
               tool_jwk_id: jwk.id
             },
             tool.deployment_id,
             conn.assigns.current_user
           ) do
      render(conn, "success.html", approved: Lti13.Registrations.approved?(registration))
    else
      error ->
        Logger.warning("LTI dynamic registration failed: #{failure_reason(error)}")

        conn
        |> put_status(:bad_request)
        |> render_error(
          gettext(
            "Registration with your platform failed. Please check your platform configuration and try again."
          )
        )
    end
  end

  def create(conn, _params) do
    conn |> put_status(:not_found) |> render(ClaperWeb.ErrorView, "404.html")
  end

  defp fetch_platform_configuration(url) do
    with {:ok, body} <- request(url, []),
         {:ok, platform} <- platform_configuration(body),
         :ok <- validate_platform_urls(Map.values(platform)) do
      {:ok, platform}
    end
  end

  defp platform_configuration(%{
         "issuer" => issuer,
         "registration_endpoint" => registration_endpoint,
         "jwks_uri" => jwks_uri,
         "authorization_endpoint" => authorization_endpoint,
         "token_endpoint" => token_endpoint
       })
       when is_binary(issuer) and issuer != "" do
    {:ok,
     %{
       issuer: issuer,
       registration_endpoint: registration_endpoint,
       jwks_uri: jwks_uri,
       authorization_endpoint: authorization_endpoint,
       token_endpoint: token_endpoint
     }}
  end

  defp platform_configuration(_body), do: {:error, :invalid_openid_configuration}

  defp register_tool(registration_endpoint, token) do
    with {:ok, body} <-
           request(registration_endpoint,
             headers: [
               {"Authorization", "Bearer #{token}"},
               {"Content-type", "application/json"},
               {"Accept", "application/json"}
             ],
             body: body()
           ) do
      case body do
        %{
          "client_id" => client_id,
          @tool_configuration_claim => %{"deployment_id" => deployment_id}
        } ->
          {:ok, %{client_id: client_id, deployment_id: deployment_id}}

        _ ->
          {:error, :invalid_registration_response}
      end
    end
  end

  defp request(url, options) do
    case Lti13.HTTP.post(url, options) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, _reason} ->
        {:error, :platform_request_failed}
    end
  end

  defp validate_platform_urls(urls) do
    Enum.reduce_while(urls, :ok, fn url, :ok ->
      case Lti13.HTTP.validate_url(url) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  # Never log platform response bodies, credentials, or query-string tokens.
  defp failure_reason({:error, reason}) when is_atom(reason), do: reason
  defp failure_reason({:error, {:unexpected_status, status}}), do: "HTTP #{status}"
  defp failure_reason(_error), do: :invalid_registration

  defp render_error(conn, msg) do
    conn
    |> put_view(ClaperWeb.Lti.LaunchView)
    |> render("error.html", msg: msg)
  end

  defp body() do
    endpoint_config = Application.get_env(:claper, ClaperWeb.Endpoint)[:url]

    default_ports = [80, 443]

    port_suffix =
      if endpoint_config[:port] in default_ports, do: "", else: ":#{endpoint_config[:port]}"

    url = "#{endpoint_config[:scheme]}://#{endpoint_config[:host]}#{port_suffix}"

    Jason.encode_to_iodata!(%{
      "application_type" => "web",
      "response_types" => ["id_token"],
      "grant_types" => ["implict", "client_credentials"],
      "initiate_login_uri" => "#{url}/lti/login",
      "redirect_uris" => [
        "#{url}/lti/launch"
      ],
      "client_name" => "Claper",
      "jwks_uri" => "#{url}/.well-known/jwks.json",
      "logo_uri" => "#{url}/images/logo.svg",
      "token_endpoint_auth_method" => "private_key_jwt",
      "scope" =>
        "https://purl.imsglobal.org/spec/lti-ags/scope/score https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly",
      @tool_configuration_claim => %{
        "domain" => "#{endpoint_config[:host]}#{port_suffix}",
        "description" => "Create interactive presentations",
        "target_link_uri" => "#{url}/lti/launch",
        "custom_parameters" => %{
          "context_start_date" => "$CourseSection.timeFrame.begin",
          "context_end_date" => "$CourseSection.timeFrame.end",
          "resource_title" => "$ResourceLink.title",
          "resource_id" => "$ResourceLink.id"
        },
        "claims" => ["iss", "sub", "name", "email"]
      }
    })
  end

  def jwks(conn, _params) do
    keys = Lti13.Jwks.get_all_public_keys()

    conn
    |> put_status(:ok)
    |> json(keys)
  end
end
