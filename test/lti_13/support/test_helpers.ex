defmodule Lti_1p3.DataProviders.EctoProvider.TestHelpers do
  import Lti_1p3.Config

  alias Lti_1p3.Test.Lti_1p3_User
  alias Lti_1p3.Jwk
  alias Lti_1p3.Tool.Registration
  alias Lti_1p3.Tool.Deployment

  Mox.defmock(Lti_1p3.Test.MockHTTPoison, for: HTTPoison.Base)

  def lti_1p3_user(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        id: 0,
        sub: "a6d5c443-1f51-4783-ba1a-7686ffe3b54a",
        name: "Ms Jane Marie Doe",
        given_name: "Jane",
        family_name: "Doe",
        middle_name: "Marie",
        picture: "https://platform.example.edu/jane.jpg",
        email: "jane#{System.unique_integer([:positive])}@platform.example.edu",
        locale: "en-US",
        platform_roles: "http://purl.imsglobal.org/vocab/lis/v2/system/person#User,http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student",
        context_roles: "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      })

    struct!(Lti_1p3_User, params)
  end

  def jwk_fixture(attrs \\ %{}) do
    %{private_key: private_key} = Lti_1p3.KeyGenerator.generate_key_pair()

    params =
      attrs
      |> Enum.into(%{
        pem: private_key,
        typ: "JWT",
        alg: "RS256",
        kid: UUID.uuid4(),
        active: true,
      })

    {:ok, jwk} = provider!().create_jwk(struct!(Jwk, params))

    jwk
  end

  def registration_fixture(%{tool_jwk_id: tool_jwk_id} = attrs) do
    params =
      attrs
      |> Enum.into(%{
        issuer: "https://lti-ri.imsglobal.org",
        client_id: "12345",
        key_set_url: "some key_set_url",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        tool_jwk_id: tool_jwk_id,
      })

     {:ok, registration} = provider!().create_registration(struct(Registration, params))

     registration
  end

  def deployment_fixture(%{deployment_id: deployment_id, registration_id: registration_id} = attrs) do
    params =
      attrs
      |> Enum.into(%{
        deployment_id: deployment_id,
        registration_id: registration_id,
      })

     {:ok, deployment} = provider!().create_deployment(struct(Deployment, params))

     deployment
  end

  def generate_id_token(jwk, kid, claims) do
    # create a signer
    signer = Joken.Signer.create("RS256", %{"pem" => jwk.pem}, %{
      "kid" => kid,
    })

    {:ok, claims} = Joken.generate_claims(%{}, claims)

    Joken.generate_and_sign!(%{}, claims, signer)
  end

  def all_default_claims() do
    %{}
    |> Map.merge(security_detail_data())
    |> Map.merge(user_detail_data())
    |> Map.merge(claims_data())
    |> Map.merge(example_extension_data())
  end

  def security_detail_data() do
    %{
      "iss" => "https://lti-ri.imsglobal.org",
      "sub" => "a73d59affc5b2c4cd493",
      "aud" => "12345",
      "exp" => Timex.now |> Timex.add(Timex.Duration.from_minutes(5)) |> Timex.to_unix,
      "iat" => Timex.now |> Timex.to_unix,
      "nonce" => UUID.uuid4(),
    }
  end

  def user_detail_data() do
    %{
      "given_name" => "Chelsea",
      "family_name" => "Conroy",
      "middle_name" => "Reichel",
      "picture" => "http://example.org/Chelsea.jpg",
      "email" => "Chelsea.Conroy@example.org",
      "name" => "Chelsea Reichel Conroy",
      "locale" => "en-US",
    }
  end

  def claims_data() do
    %{
      "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint" => %{
        "lineitems" => "https://lti-ri.imsglobal.org/platforms/1237/contexts/10337/line_items",
        "scope" => ["https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
        "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly"]
      },
      "https://purl.imsglobal.org/spec/lti-ces/claim/caliper-endpoint-service" => %{
        "caliper_endpoint_url" => "https://lti-ri.imsglobal.org/platforms/1237/sensors",
        "caliper_federated_session_id" => "urn:uuid:7bec5956c5297eacf382",
        "scopes" => ["https://purl.imsglobal.org/spec/lti-ces/v1p0/scope/send"]
      },
      "https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice" => %{
        "context_memberships_url" => "https://lti-ri.imsglobal.org/platforms/1237/contexts/10337/memberships",
        "service_versions" => ["2.0"]
      },
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => "10337",
        "label" => "My Course",
        "title" => "My Course",
        "type" => ["Course"]
      },
      "https://purl.imsglobal.org/spec/lti/claim/custom" => %{
        "myCustomValue" => "123"
      },
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => "1",
      "https://purl.imsglobal.org/spec/lti/claim/launch_presentation" => %{
        "document_target" => "iframe",
        "height" => 320,
        "return_url" => "https://lti-ri.imsglobal.org/platforms/1237/returns",
        "width" => 240
      },
      "https://purl.imsglobal.org/spec/lti/claim/message_type" => "LtiResourceLinkRequest",
      "https://purl.imsglobal.org/spec/lti/claim/resource_link" => %{
        "description" => "my course",
        "id" => "20052",
        "title" => "My Course"
      },
      "https://purl.imsglobal.org/spec/lti/claim/role_scope_mentor" => ["a62c52c02ba262003f5e"],
      "https://purl.imsglobal.org/spec/lti/claim/roles" => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student",
      "http://purl.imsglobal.org/vocab/lis/v2/membership#Mentor"],
      "https://purl.imsglobal.org/spec/lti/claim/target_link_uri" => "https://lti-ri.imsglobal.org/lti/tools/1193/launches",
      "https://purl.imsglobal.org/spec/lti/claim/tool_platform" => %{
        "contact_email" => "",
        "description" => "",
        "guid" => 1237,
        "name" => "lti-test",
        "product_family_code" => "",
        "url" => "",
        "version" => "1.0"
      },
      "https://purl.imsglobal.org/spec/lti/claim/version" => "1.3.0",
    }
  end

  def example_extension_data() do
    %{
      "https://www.example.com/extension" => %{"color" => "violet"},
    }
  end

  def mock_get_jwk_keys(jwk) do
    body = Jason.encode!(%{
      keys: [
        jwk.pem
        |> JOSE.JWK.from_pem()
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> (fn {_kty, public_jwk} -> public_jwk end).()
        |> Map.put("typ", jwk.typ)
        |> Map.put("alg", jwk.alg)
        |> Map.put("kid", jwk.kid)
        |> Map.put("use", "sig")
      ]
    })

    {:ok, %HTTPoison.Response{status_code: 200, body: body}}
  end
end
