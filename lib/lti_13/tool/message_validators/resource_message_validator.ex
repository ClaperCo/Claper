defmodule Lti13.Tool.MessageValidators.ResourceMessageValidator do
  def can_validate(jwt_body) do
    jwt_body["https://purl.imsglobal.org/spec/lti/claim/message_type"] == "LtiResourceLinkRequest"
  end

  def validate(jwt_body) do
    with {:ok} <- user_sub(jwt_body),
         {:ok} <- lti_version(jwt_body),
         {:ok} <- roles_claim(jwt_body),
         {:ok} <- resource_link_id(jwt_body) do
      {:ok}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp user_sub(jwt_body) do
    case jwt_body["sub"] do
      nil ->
        {:error, "Must have a user (sub)"}

      _ ->
        {:ok}
    end
  end

  defp lti_version(jwt_body) do
    if jwt_body["https://purl.imsglobal.org/spec/lti/claim/version"] != "1.3.0" do
      {:error, "Incorrect version, expected 1.3.0"}
    else
      {:ok}
    end
  end

  defp roles_claim(jwt_body) do
    case jwt_body["https://purl.imsglobal.org/spec/lti/claim/roles"] do
      nil ->
        {:error, "Missing Roles Claim"}

      _ ->
        {:ok}
    end
  end

  defp resource_link_id(jwt_body) do
    case jwt_body["https://purl.imsglobal.org/spec/lti/claim/resource_link"]["id"] do
      nil ->
        {:error, "Missing Resource Link Id"}

      _ ->
        {:ok}
    end
  end
end
