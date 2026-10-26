defmodule Lti13.Users do
  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Lti13.Users.User

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def get_user_by_sub_and_registration_id(sub, registration_id) do
    Repo.get_by(User, sub: sub, registration_id: registration_id)
  end

  def get_all_users_by_user_id(user_id) do
    Repo.all(from u in User, where: u.user_id == ^user_id, preload: [registration: :user])
  end

  @legacy_approval_limit 5
  @legacy_approval_interval_ms 60_000

  @doc """
  Approves a legacy LTI identity mapping (created before provisioning was tracked)
  for its owner after re-checking the owner's local password.

  Only mappings belonging to an administrator-approved platform can be approved.
  Attempts are rate limited per user to prevent password guessing.
  """
  def authorize_legacy_user(%Claper.Accounts.User{} = claper_user, mapping_id, password)
      when is_binary(password) and is_integer(mapping_id) do
    case Claper.RateLimit.hit(
           "lti_legacy_approval:#{claper_user.id}",
           @legacy_approval_interval_ms,
           @legacy_approval_limit
         ) do
      {:allow, _count} ->
        do_authorize_legacy_user(claper_user, mapping_id, password)

      {:deny, retry_after} ->
        Claper.Audit.Security.record(
          claper_user,
          "security.rate_limit_exceeded",
          %{
            reason: "lti_legacy_approval",
            resource_type: "lti_identity",
            limit: @legacy_approval_limit,
            interval_ms: @legacy_approval_interval_ms,
            retry_after_ms: retry_after
          },
          1
        )

        {:error, %{reason: :rate_limited, msg: "Too many attempts"}}
    end
  end

  def authorize_legacy_user(_, _, _), do: invalid_user()

  defp do_authorize_legacy_user(claper_user, mapping_id, password) do
    # An old LTI session is not proof of local ownership: require fresh local credentials.
    case Claper.Accounts.get_user_by_email_and_password(claper_user.email, password) do
      %Claper.Accounts.User{id: id} when id == claper_user.id ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        case Repo.update_all(
               from(u in User,
                 join: r in assoc(u, :registration),
                 where:
                   u.id == ^mapping_id and u.user_id == ^id and is_nil(u.provisioned_at) and
                     not is_nil(r.approved_at)
               ),
               set: [authorized_at: now, updated_at: now]
             ) do
          {1, _} -> {:ok}
          _ -> invalid_user()
        end

      _ ->
        invalid_user()
    end
  end

  def remove_user(claper_user, registration_id) do
    Repo.delete_all(
      from u in User,
        where: u.registration_id == ^registration_id and u.user_id == ^claper_user.id
    )
  end

  def get_or_create_user(
        %{
          sub: sub,
          email: email,
          registration_id: registration_id
        } = attrs
      ) do
    case get_user_by_sub_and_registration_id(sub, registration_id) do
      nil ->
        create_new_user(attrs, email, registration_id)

      %User{provisioned_at: nil, authorized_at: nil} ->
        invalid_user()

      %User{} = user ->
        reuse_bound_user(user, attrs)
    end
  end

  defp reuse_bound_user(user, attrs) do
    case Claper.Accounts.get_user(user.user_id) do
      nil ->
        invalid_user()

      claper_user ->
        with {:ok, _} <- Claper.Accounts.fill_missing_user_names(claper_user, attrs) do
          {:ok, Repo.preload(user, :user, force: true)}
        end
    end
  end

  defp create_new_user(attrs, email, registration_id) do
    # Never infer ownership of an existing account from a platform's email claim.
    # The account insert's unique email constraint also closes concurrent linking races.
    result =
      Repo.transaction(fn ->
        account_attrs = %{
          email: email,
          confirmed_at: DateTime.utc_now(),
          is_randomized_password: true,
          password: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
          first_name: attrs[:first_name],
          last_name: attrs[:last_name]
        }

        with {:ok, claper_user} <- Claper.Accounts.create_user(account_attrs),
             changeset <-
               User.changeset(
                 %User{},
                 Map.merge(attrs, %{
                   user_id: claper_user.id,
                   registration_id: registration_id
                 })
               ),
             changeset <-
               Ecto.Changeset.put_change(
                 changeset,
                 :provisioned_at,
                 NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
               ),
             {:ok, user} <- Repo.insert(changeset) do
          Repo.preload(user, :user)
        else
          _ -> Repo.rollback(:invalid_user)
        end
      end)

    case result do
      {:ok, user} -> {:ok, user}
      {:error, _} -> invalid_user()
    end
  end

  defp invalid_user do
    {:error,
     %{
       reason: :invalid_user,
       msg: "Sign in locally and approve this LMS identity in account settings before using it."
     }}
  end
end
