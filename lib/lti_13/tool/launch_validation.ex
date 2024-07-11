defmodule Lti13.Tool.LaunchValidation do
  import Lti13.Jwks.Validator

  alias Lti13.Deployments
  alias Lti13.Registrations

  @message_validators [
    Lti13.Tool.MessageValidators.ResourceMessageValidator
  ]

  @authorized_to_create_event_roles [
    "http://purl.imsglobal.org/vocab/lis/v2/membership#Administrator",
    "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
  ]

  @doc """
  Validates an incoming LTI 1.3 launch and returns the claims if successful.
  """
  def validate(params, session_state, _opts \\ []) do
    with {:ok} <- validate_oidc_state(params, session_state),
         {:ok, registration} <- validate_registration(params),
         {:ok, key_set_url} <- registration_key_set_url(registration),
         {:ok, id_token} <- extract_param(params, "id_token"),
         {:ok, jwt_body} <- validate_jwt_signature(id_token, key_set_url),
         {:ok} <- validate_timestamps(jwt_body),
         {:ok} <- validate_deployment(registration, jwt_body),
         {:ok} <- validate_message(jwt_body),
         {:ok, lti_user} <- validate_user(jwt_body),
         {:ok} <- validate_nonce(lti_user, jwt_body, "validate_launch"),
         {:ok, is_instructor} <- validate_role(jwt_body),
         {:ok, resource} <- validate_resource(jwt_body, lti_user, registration, is_instructor),
         claims <- jwt_body do
      {:ok, %{claims: claims, lti_user: lti_user, resource: resource}}
    end
  end

  # Validate that the state sent with an OIDC launch matches the state that was sent in the OIDC response
  # returns a boolean on whether it is valid or not
  defp validate_oidc_state(params, session_state) do
    case session_state do
      nil ->
        {:error,
         %{
           reason: :invalid_oidc_state,
           msg:
             "State from session is missing. Make sure cookies are enabled and configured correctly"
         }}

      session_state ->
        case params["state"] do
          nil ->
            {:error, %{reason: :invalid_oidc_state, msg: "State from OIDC request is missing"}}

          request_state ->
            if request_state == session_state do
              {:ok}
            else
              {:error,
               %{
                 reason: :invalid_oidc_state,
                 msg: "State from OIDC request does not match session"
               }}
            end
        end
    end
  end

  defp validate_registration(params) do
    with {:ok, issuer, client_id} <- peek_issuer_client_id(params) do
      case Registrations.get_registration_by_issuer_client_id(issuer, client_id) do
        nil ->
          {:error,
           %{
             reason: :invalid_registration,
             msg:
               "Registration with issuer \"#{issuer}\" and client id \"#{client_id}\" not found",
             issuer: issuer,
             client_id: client_id
           }}

        registration ->
          {:ok, registration}
      end
    end
  end

  @spec validate_resource(
          map(),
          Lti13.Users.User.t(),
          Lti13.Registrations.Registration.t(),
          boolean()
        ) :: {:ok, Lti13.Resources.Resource.t()} | {:error, map()}
  defp validate_resource(
         %{
           "https://purl.imsglobal.org/spec/lti/claim/custom" => %{
             "resource_title" => title,
             "resource_id" => resource_id
           }
         },
         lti_user,
         registration,
         is_instructor
       ) do
    case Lti13.Resources.get_resource_by_id_and_registration(resource_id, registration.id) do
      nil ->
        case is_instructor do
          true ->
            case Lti13.Resources.create_resource_with_event(%{
                   title: title,
                   resource_id: resource_id,
                   lti_user: lti_user
                 }) do
              {:ok, resource} ->
                {:ok, resource}

              {:error, _} ->
                {:error, %{reason: :invalid_resource, msg: "Failed to create resource"}}
            end

          false ->
            {:error,
             %{reason: :invalid_resource, msg: "User is not authorized to create resource"}}
        end

      resource ->
        case is_instructor do
          true ->
            with activity_leaders <-
                   Claper.Events.get_activity_leaders_for_event(resource.event_id),
                 activity_leaders_emails <- Enum.map(activity_leaders, fn al -> al.email end) do
              if lti_user.email not in activity_leaders_emails &&
                   resource.event.user_id != lti_user.user_id do
                Claper.Events.create_activity_leader(%{
                  email: lti_user.email,
                  user_id: lti_user.id,
                  event_id: resource.event_id
                })
              end
            end

            {:ok, resource}

          false ->
            {:ok, resource}
        end
    end
  end

  defp validate_role(jwt) do
    roles = jwt["https://purl.imsglobal.org/spec/lti/claim/roles"]
    is_instructor = Enum.any?(roles, fn role -> role in @authorized_to_create_event_roles end)
    {:ok, is_instructor}
  end

  defp peek_issuer_client_id(params) do
    with {:ok, jwt_string} <- extract_param(params, "id_token"),
         {:ok, jwt_claims} <- peek_claims(jwt_string) do
      {:ok, jwt_claims["iss"], peek_client_id(jwt_claims["aud"])}
    end
  end

  defp peek_client_id([client_id | _]), do: client_id
  defp peek_client_id(client_id), do: client_id

  defp validate_deployment(registration, jwt_body) do
    deployment_id = jwt_body["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
    deployment = Deployments.get_deployment(registration.id, deployment_id)

    case deployment do
      nil ->
        {:error,
         %{
           reason: :invalid_deployment,
           msg: "Deployment with id \"#{deployment_id}\" not found",
           registration_id: registration.id,
           deployment_id: deployment_id
         }}

      _deployment ->
        {:ok}
    end
  end

  defp validate_message(jwt_body) do
    case jwt_body["https://purl.imsglobal.org/spec/lti/claim/message_type"] do
      nil ->
        {:error, %{reason: :invalid_message_type, msg: "Missing message type"}}

      message_type ->
        # no more than one message validator should apply for a given mesage,
        # so use the first validator we find that applies
        validation_result =
          case Enum.find(@message_validators, fn mv -> mv.can_validate(jwt_body) end) do
            nil -> nil
            validator -> validator.validate(jwt_body)
          end

        case validation_result do
          nil ->
            {:error,
             %{
               reason: :invalid_message_type,
               msg: "Invalid or unsupported message type \"#{message_type}\""
             }}

          {:error, error} ->
            {:error,
             %{
               reason: :invalid_message,
               msg: "Message validation failed: (\"#{message_type}\") #{error}"
             }}

          _ ->
            {:ok}
        end
    end
  end
end
