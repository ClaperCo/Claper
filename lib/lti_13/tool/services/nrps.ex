defmodule Lti13.Tool.Services.NRPS do
  @moduledoc """
  Implementation of LTI Names and Roles Provisioning Service (NRPS) version 2.0.

  For information on the standard, see:
  https://www.imsglobal.org/spec/lti-nrps/v2p0
  """

  @lti_nrps_claim_url "https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice"
  @context_memberships_url_key "context_memberships_url"

  alias Lti13.Tool.Services.AccessToken
  alias Lti13.Tool.Services.NRPS.Membership

  require Logger

  defp to_membership(raw) do
    %Membership{
      status: Map.get(raw, "status"),
      name: Map.get(raw, "name"),
      picture: Map.get(raw, "picture"),
      given_name: Map.get(raw, "given_name"),
      middle_name: Map.get(raw, "middle_name"),
      family_name: Map.get(raw, "family_name"),
      email: Map.get(raw, "email"),
      user_id: Map.get(raw, "user_id"),
      roles: Map.get(raw, "roles")
    }
  end

  def fetch_memberships(context_memberships_url, %AccessToken{} = access_token) do
    Logger.debug("Fetch memberships from #{context_memberships_url}")

    url = context_memberships_url <> "?limit=1000"

    with {:ok, %Req.Response{status: 200, body: body}} <-
           Req.get(url, headers: headers(access_token)),
         {:ok, results} <- Jason.decode(body),
         members <- Map.get(results, "members") do
      {:ok, Enum.map(members, fn r -> to_membership(r) end)}
    else
      e ->
        Logger.error("Error encountered fetching memberships from #{url} #{inspect(e)}")
        {:error, "Error retrieving memberships"}
    end
  end

  @doc """
  Returns true if nrps is enabled (that is, to allow a context membership query).
  """
  def nrps_enabled?(lti_launch_params) do
    case Map.get(lti_launch_params, @lti_nrps_claim_url) do
      nil -> false
      config -> Map.has_key?(config, @context_memberships_url_key)
    end
  end

  @doc """
  Returns the required scopes for the NRPS service.
  """
  def required_scopes() do
    [
      @context_memberships_url_key
    ]
  end

  @doc """
  Returns the context memberships URL from LTI launch params. If not present returns nil.
  """
  def get_context_memberships_url(lti_launch_params) do
    Map.get(lti_launch_params, @lti_nrps_claim_url, %{}) |> Map.get(@context_memberships_url_key)
  end

  defp headers(%AccessToken{} = access_token) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{access_token.access_token}"},
      {"Accept", "application/vnd.ims.lti-nrps.v2.membershipcontainer+json"}
    ]
  end
end
