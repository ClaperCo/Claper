defmodule Lti13.Tool.Services.AGS do
  @moduledoc """
  Implementation of LTI Assignment and Grading Services (AGS) version 2.0.

  For information on the standard, see:
  https://www.imsglobal.org/spec/lti-ags/v2p0/
  """

  @lti_ags_claim_url "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint"
  @lineitem_scope_url "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"
  @scores_scope_url "https://purl.imsglobal.org/spec/lti-ags/scope/score"

  alias Lti13.Tool.Services.AGS.Score
  alias Lti13.Tool.Services.AGS.LineItem
  alias Lti13.Tool.Services.AccessToken

  @doc """
  Post a score to an existing line item, using an already acquired access token.
  """
  def post_score(%Score{} = score, %LineItem{} = line_item, %AccessToken{} = access_token) do
    body = score |> Jason.encode!()

    case Req.post(
           build_url_with_path(line_item.id, "scores"),
           body: body,
           headers: score_headers(access_token)
         ) do
      {:ok, %Req.Response{status: code, body: body}} when code in [200, 201] ->
        {:ok, body}

      _e ->
        {:error, "Error posting score"}
    end
  end

  @doc """
  Creates a line item for a resource id, if one does not exist.  Whether or not the
  line item is created or already exists, this function returns a line item struct wrapped
  in a {:ok, line_item} tuple.  On error, returns a {:error, error} tuple.
  """
  def fetch_or_create_line_item(
        line_items_service_url,
        resource_id,
        maximum_score_provider,
        label,
        %AccessToken{} = access_token
      ) do
    with {:ok, %Req.Response{status: code, body: body}} when code in [200, 201] <-
           Req.get(line_items_service_url, headers: headers(access_token)),
         result <- if(is_binary(body), do: Jason.decode!(body), else: body) do
      process_line_items(
        result,
        line_items_service_url,
        resource_id,
        maximum_score_provider,
        label,
        access_token
      )
    else
      _error -> {:error, "Error retrieving existing line items"}
    end
  end

  defp process_line_items(
         [],
         line_items_service_url,
         resource_id,
         maximum_score_provider,
         label,
         access_token
       ) do
    create_line_item(
      line_items_service_url,
      resource_id,
      maximum_score_provider.(),
      label,
      access_token
    )
  end

  defp process_line_items(
         [raw_line_item | _],
         _url,
         _resource_id,
         _score_provider,
         label,
         access_token
       ) do
    line_item = to_line_item(raw_line_item)

    if line_item.label != label do
      update_line_item(line_item, %{label: label}, access_token)
    else
      {:ok, line_item}
    end
  end

  defp to_line_item(raw_line_item) do
    %LineItem{
      id: Map.get(raw_line_item, "id"),
      scoreMaximum: Map.get(raw_line_item, "scoreMaximum"),
      resourceId: Map.get(raw_line_item, "resourceId"),
      label: Map.get(raw_line_item, "label")
    }
  end

  def fetch_line_items(line_items_service_url, %AccessToken{} = access_token) do
    # Unfortunately, at least Canvas implements a default limit of 10 line items
    # when one makes a request without a 'limit' parameter specified. Setting it explicitly to 1000
    # bypasses this default limit, of course, and works in all cases until a course more than
    # a thousand grade book entries.
    url = build_url_with_params(line_items_service_url, "limit=1000")

    case Req.get(url, headers: headers(access_token)) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        results = if is_binary(body), do: Jason.decode!(body), else: body
        {:ok, Enum.map(results, fn r -> to_line_item(r) end)}

      _e ->
        {:error, "Error retrieving all line items"}
    end
  end

  @doc """
  Creates a line item for a resource id. This function returns a line item struct wrapped
  in a {:ok, line_item} tuple.  On error, returns a {:error, error} tuple.
  """
  def create_line_item(
        line_items_service_url,
        resource_id,
        score_maximum,
        label,
        %AccessToken{} = access_token
      ) do
    line_item = %LineItem{
      scoreMaximum: score_maximum,
      resourceId: LineItem.to_resource_id(resource_id),
      label: label
    }

    body = line_item |> Jason.encode!()

    case Req.post(line_items_service_url, body: body, headers: headers(access_token)) do
      {:ok, %Req.Response{status: code, body: body}} when code in [200, 201] ->
        result = if is_binary(body), do: Jason.decode!(body), else: body
        {:ok, to_line_item(result)}

      _ ->
        {:error, "Error creating new line item"}
    end
  end

  @doc """
  Updates an existing line item. On success returns
  a {:ok, line_item} tuple.  On error, returns a {:error, error} tuple.
  """
  def update_line_item(%LineItem{} = line_item, changes, %AccessToken{} = access_token) do
    updated_line_item = %LineItem{
      id: line_item.id,
      scoreMaximum: Map.get(changes, :scoreMaximum, line_item.scoreMaximum),
      resourceId: line_item.resourceId,
      label: Map.get(changes, :label, line_item.label)
    }

    body = updated_line_item |> Jason.encode!()

    # The line_item endpoint defines a PUT operation to update existing line items.  The
    # url to use is the id of the line item
    url = line_item.id

    case Req.put(url, body: body, headers: headers(access_token)) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        result = if is_binary(body), do: Jason.decode!(body), else: body
        {:ok, to_line_item(result)}

      _e ->
        {:error, "Error updating existing line item"}
    end
  end

  @doc """
  Returns true if grade pass back service is enabled with the necessary scopes. The
  necessary scopes are the line item scope to read all line items and create new ones
  and the scores scope, to be able to post new scores. Also verifies that the line items
  endpoint is present.
  """
  def grade_passback_enabled?(lti_launch_params) do
    case Map.get(lti_launch_params, @lti_ags_claim_url) do
      nil ->
        false

      config ->
        Map.has_key?(config, "lineitems") and has_scope?(config, @lineitem_scope_url) and
          has_scope?(config, @scores_scope_url)
    end
  end

  @doc """
  Returns the line items URL from LTI launch params.
  If not present returns nil.
  If a registration is present, uses the auth server domain + the line items path.
  """
  def get_line_items_url(lti_launch_params, registration \\ %{}) do
    line_items_url =
      lti_launch_params
      |> Map.get(@lti_ags_claim_url, %{})
      |> Map.get("lineitems")

    unless is_nil(line_items_url) do
      %URI{path: line_items_path} = URI.parse(line_items_url)

      registration
      |> get_line_items_domain(line_items_url)
      |> URI.parse()
      |> Map.put(:path, line_items_path)
      |> URI.to_string()
    end
  end

  defp get_line_items_domain(%{line_items_service_domain: domain}, default)
       when is_nil(domain) or domain == "",
       do: default

  defp get_line_items_domain(%{line_items_service_domain: domain}, _default), do: domain
  defp get_line_items_domain(_registration, default), do: default

  @doc """
  Returns true if the LTI AGS claim has a particular scope url, false if it does not.
  """
  def has_scope?(lti_ags_claim, scope_url) do
    case Map.get(lti_ags_claim, "scope", [])
         |> Enum.find(nil, fn url -> scope_url == url end) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Returns the required scopes for the AGS service.
  """
  def required_scopes() do
    [
      @lineitem_scope_url,
      @scores_scope_url
    ]
  end

  # ---------------------------------------------------------
  # Helpers to build headers correctly
  defp headers(%AccessToken{} = access_token) do
    [
      {"Accept", "application/vnd.ims.lis.v2.lineitemcontainer+json"},
      {"Content-Type", "application/vnd.ims.lis.v2.lineitem+json"}
    ] ++ access_token_header(access_token.access_token)
  end

  defp score_headers(%AccessToken{} = access_token) do
    [{"Content-Type", "application/vnd.ims.lis.v1.score+json"}] ++
      access_token_header(access_token.access_token)
  end

  defp access_token_header(access_token),
    do: [{"Authorization", "Bearer #{access_token}"}]

  # ---------------------------------------------------------
  # Helpers to build urls correctly (if base url contian query params)
  defp build_url_with_path(base_url, path_to_add) do
    case String.split(base_url, "?") do
      [base_url, query_params] -> "#{base_url}/#{path_to_add}?#{query_params}"
      _ -> "#{base_url}/#{path_to_add}"
    end
  end

  defp build_url_with_params(base_url, params_to_add) do
    case String.split(base_url, "?") do
      [base_url, query_params] -> "#{base_url}?#{query_params}&#{params_to_add}"
      _ -> "#{base_url}?#{params_to_add}"
    end
  end
end
