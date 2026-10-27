defmodule Lti13.LaunchStatesTest do
  use Claper.DataCase

  import Lti13.RegistrationsFixtures
  alias Lti13.LaunchStates
  alias Lti13.LaunchStates.LaunchState

  test "issued challenges expire after ten minutes" do
    registration = registration_fixture()
    assert {:ok, challenge} = LaunchStates.create(registration.id)

    expired =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-601, :second)
      |> NaiveDateTime.truncate(:second)

    Repo.update_all(from(s in LaunchState, where: s.id == ^challenge.id),
      set: [inserted_at: expired]
    )

    assert {:error, %{reason: :invalid_nonce}} =
             LaunchStates.consume(challenge.state, challenge.nonce, registration.id)
  end

  test "only one concurrent callback consumes an initiated challenge" do
    registration = registration_fixture()
    assert {:ok, challenge} = LaunchStates.create(registration.id)

    results =
      1..2
      |> Enum.map(fn _ ->
        Task.async(fn ->
          LaunchStates.consume(challenge.state, challenge.nonce, registration.id)
        end)
      end)
      |> Enum.map(&Task.await/1)

    assert Enum.count(results, &(&1 == {:ok})) == 1
    assert Enum.count(results, &match?({:error, %{reason: :invalid_nonce}}, &1)) == 1
  end

  test "nonce and registration must both match initiation" do
    registration = registration_fixture()
    other = registration_fixture()
    assert {:ok, challenge} = LaunchStates.create(registration.id)

    assert {:error, %{reason: :invalid_nonce}} =
             LaunchStates.consume(challenge.state, "unsolicited-nonce", registration.id)

    assert {:error, %{reason: :invalid_nonce}} =
             LaunchStates.consume(challenge.state, challenge.nonce, other.id)

    assert {:ok} = LaunchStates.consume(challenge.state, challenge.nonce, registration.id)
  end
end
