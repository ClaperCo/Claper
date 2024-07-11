defmodule ClaperWeb.Lti.RegistrationController do
  use ClaperWeb, :controller

  def new(conn, %{"openid_configuration" => conf, "registration_token" => token}) do
    render(conn, "new.html", conf: conf, token: token)
  end

  def new(conn, _params) do
    conn |> render(ClaperWeb.ErrorView, "404.html")
  end

  def create(conn, params) do
    jwk = Lti13.Jwks.get_active_jwk()

    %{"openid_configuration" => conf, "registration_token" => token} = params

    body = Req.post!(conf).body

    %{
      "issuer" => issuer,
      "registration_endpoint" => reg_endpoint,
      "jwks_uri" => jwks_uri,
      "authorization_endpoint" => auth_endpoint,
      "token_endpoint" => token_endpoint
    } = body

    body =
      Req.post!(reg_endpoint,
        headers: [
          {"Authorization", "Bearer #{token}"},
          {"Content-type", "application/json"},
          {"Accept", "application/json"}
        ],
        body: body()
      ).body

    %{
      "client_id" => client_id,
      "https://purl.imsglobal.org/spec/lti-tool-configuration" => %{
        "deployment_id" => deployment_id
      }
    } = body

    {:ok, registration} =
      Lti13.Registrations.create_registration(%{
        issuer: issuer,
        client_id: client_id,
        key_set_url: jwks_uri,
        auth_token_url: token_endpoint,
        auth_login_url: auth_endpoint,
        auth_server: issuer,
        tool_jwk_id: jwk.id
      })

    {:ok, _deployment} =
      Lti13.Deployments.create_deployment(%{
        deployment_id: deployment_id,
        registration_id: registration.id
      })

    render(conn, "success.html")
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
      "https://purl.imsglobal.org/spec/lti-tool-configuration" => %{
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
