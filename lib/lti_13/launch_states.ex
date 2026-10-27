defmodule Lti13.LaunchStates do
  import Ecto.Query
  alias Claper.Repo
  alias Lti13.LaunchStates.LaunchState

  @ttl_seconds 600

  def create(registration_id) do
    # Expired challenges must not accumulate when a platform never completes login.
    Repo.delete_all(from s in LaunchState, where: s.inserted_at <= ^expiry())

    %LaunchState{}
    |> LaunchState.changeset(%{
      state: random_token(),
      nonce: random_token(),
      registration_id: registration_id
    })
    |> Repo.insert()
  end

  def consume(state, nonce, registration_id)
      when is_binary(state) and is_binary(nonce) and is_integer(registration_id) do
    # Atomic deletion makes the challenge single-use even with simultaneous callbacks
    # or replay of an old signed session cookie.
    case Repo.delete_all(
           from s in LaunchState,
             where:
               s.state == ^state and s.nonce == ^nonce and
                 s.registration_id == ^registration_id and s.inserted_at > ^expiry()
         ) do
      {1, _} -> {:ok}
      _ -> invalid_nonce()
    end
  end

  def consume(_, _, _), do: invalid_nonce()

  defp expiry do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-@ttl_seconds, :second)
    |> NaiveDateTime.truncate(:second)
  end

  defp random_token, do: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

  defp invalid_nonce do
    {:error,
     %{
       reason: :invalid_nonce,
       msg: "LTI login has expired, was already used, or does not match initiation"
     }}
  end
end
