defmodule Claper.Audit.Security do
  @moduledoc """
  Bounded security observations, not findings of malicious intent.

  Counters use the existing node-local limiter. At most one record is written per
  actor/action/resource type/reason each minute, with a node-wide cap of 200 writes
  and 10,000 tracked observations per minute. Resource IDs do not create counters.
  """
  require Logger

  alias Claper.{Audit, RateLimit}

  @window_ms 60_000
  @metadata_keys ~w(reason resource_type resource_id event_id ip_address attendee_fingerprint request_id route method limit interval_ms retry_after_ms)a

  def record(user, action, metadata, threshold \\ 3)
      when action in ["security.rate_limit_exceeded", "security.suspicious_submission"] and
             is_map(metadata) and is_integer(threshold) and threshold > 0 do
    metadata = sanitize(metadata)
    actor = actor_key(user, metadata)
    key = {:security_observation, actor, action, metadata[:resource_type], metadata[:reason]}

    with {:allow, _} <- RateLimit.hit(:security_observation_budget, @window_ms, 10_000),
         {:allow, ^threshold} <- RateLimit.hit(key, @window_ms, threshold),
         {:allow, _} <- RateLimit.hit(:security_log_budget, @window_ms, 200) do
      Audit.create_log(%{
        user_id: if(user, do: user.id),
        action: action,
        resource_type: metadata[:resource_type],
        resource_id: metadata[:resource_id],
        metadata: Map.merge(metadata, %{observed_count: threshold, window_ms: @window_ms})
      })
    end

    :ok
  rescue
    error in [
      Ecto.ConstraintError,
      Ecto.InvalidChangesetError,
      DBConnection.ConnectionError,
      Postgrex.Error
    ] ->
      Logger.warning("Security audit write failed: #{inspect(error.__struct__)}")
      :ok
  end

  def fingerprint(identifier) when is_binary(identifier) do
    :crypto.mac(:hmac, :sha256, ClaperWeb.Endpoint.config(:secret_key_base), identifier)
    |> Base.encode16(case: :lower)
  end

  def fingerprint(_), do: nil

  defp actor_key(%Claper.Accounts.User{id: id}, _metadata), do: {:user, id}
  defp actor_key(nil, metadata), do: {metadata[:ip_address], metadata[:attendee_fingerprint]}

  defp sanitize(metadata) do
    metadata
    |> Map.take(@metadata_keys)
    |> Map.new(fn
      {key, value} when is_binary(value) -> {key, String.slice(value, 0, 160)}
      {key, value} when is_integer(value) or is_nil(value) -> {key, value}
      {key, _} -> {key, nil}
    end)
  end
end
