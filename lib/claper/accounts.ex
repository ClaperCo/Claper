defmodule Claper.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Claper.Accounts
  alias Claper.Repo

  alias Claper.Accounts.{User, UserToken, UserNotifier, Role}

  @doc """
  Creates a user.

  ## Examples
      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_user(attrs) do
    # Get user role if not explicitly set
    attrs = maybe_set_default_role(attrs)

    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert(returning: [:uuid])
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.get_by(email: email)
  end

  @doc """
  Gets a user by email and creates a new user if the user does not exist.

  ## Examples
      iex> get_user_by_email_or_create("foo@example.com")
      %User{}
      iex> get_user_by_email_or_create("unknown@example.com")
      %User{}
  """
  def get_user_by_email_or_create(email) when is_binary(email) do
    case get_user_by_email(email) do
      nil ->
        attrs = %{
          email: email,
          confirmed_at: DateTime.utc_now(),
          is_randomized_password: true,
          password: :crypto.strong_rand_bytes(32)
        }

        # Set default role if not explicitly set
        attrs = maybe_set_default_role(attrs)

        create_user(attrs)

      user ->
        {:ok, user}
    end
  end

  @doc """
  Lists all users that are not deleted.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users(preload \\ []) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = User |> where([u], u.email == ^email and is_nil(u.deleted_at)) |> Repo.one()
    if user && User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.get(id)
  end

  @doc """
  Soft deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    user
    |> User.delete_changeset()
    |> Repo.update()
  end

  @doc """
  Returns true if the user has been soft deleted.
  """
  def deleted?(%User{} = user) do
    not is_nil(user.deleted_at)
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    # Get user role if not explicitly set
    attrs = maybe_set_default_role(attrs)

    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert(returning: [:uuid])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes for admin operations.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.admin_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates a user for admin operations.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.admin_changeset(attrs)
    |> Repo.update()
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user preferences.

  ## Examples

      iex> change_user_preferences(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_preferences(user, attrs \\ %{}) do
    User.preferences_changeset(user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, attrs) do
    user
    |> User.email_changeset(attrs)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset = user |> User.email_changeset(%{email: email}) |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Updates the user password.
  ## Examples
      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}
      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}
  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  # Alternative version with different signature - keeping for compatibility
  def update_user_password(user, %{"current_password" => curr_pw} = attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(curr_pw)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Sets the user password.
  ## Examples
      iex> set_user_password(user, %{password: ...})
      {:ok, %User{}}
      iex> set_user_password(user, %{password: ...})
      {:error, %Ecto.Changeset{}}
  """
  def set_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs |> Map.put("is_randomized_password", false))
    |> Repo.update()
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates the user preferences.
  ## Examples
      iex> update_user_preferences(user, %{locale: "en})
      {:ok, %User{}}
      iex> update_user_preferences(user, %{locale: "invalid})
      {:error, %Ecto.Changeset{}}
  """
  def update_user_preferences(user, attrs \\ %{}) do
    user
    |> User.preferences_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delivers the magic link email to the given user.

  ## Examples

      iex> deliver_magic_link(user, &url(~p"/users/magic/&1"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_magic_link(email, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_magic_token(email, "magic")

    Repo.insert!(user_token)
    UserNotifier.deliver_magic_link(email, magic_link_url_fun.(encoded_token))
    {:ok, encoded_token}
  end

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &Routes.user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
    {:ok, encoded_token}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Verify the token for a given user email is valid.
  """
  def magic_token_valid?(email) do
    query = UserToken.user_magic_and_contexts_expiry_query(email)
    Repo.exists?(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
      {:ok, encoded_token}
    end
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &Routes.user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)

    UserNotifier.deliver_reset_password_instructions(
      user,
      reset_password_url_fun.(encoded_token)
    )
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  def confirm_magic(token) do
    with {:ok, query} <- UserToken.verify_magic_token_query(token, "magic"),
         %UserToken{} = token <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_magic_multi(token)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_magic_multi(%UserToken{} = token) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:run, fn repo, _changes ->
      user = repo.get_by(User, email: token.sent_to)

      if is_nil(user) do
        UserNotifier.deliver_welcome(token.sent_to)
      end

      {:ok, user || %User{email: token.sent_to}}
    end)
    |> Ecto.Multi.insert_or_update(:user, fn %{run: user} -> User.confirm_changeset(user) end)
    |> Ecto.Multi.delete_all(
      :tokens,
      UserToken.user_magic_and_contexts_query(token.sent_to, ["magic"])
    )
  end

  ## OIDC

  def create_oidc_user(attrs) do
    %Accounts.Oidc.User{}
    |> Accounts.Oidc.User.changeset(attrs)
    |> Repo.insert()
  end

  def remove_oidc_user(claper_user, issuer) do
    Repo.delete_all(
      from u in Accounts.Oidc.User,
        where: u.issuer == ^issuer and u.user_id == ^claper_user.id
    )
  end

  def get_all_oidc_users_by_email(email) do
    Repo.all(from u in Accounts.Oidc.User, where: u.email == ^email)
  end

  def get_oidc_user_by_sub(sub) do
    Repo.get_by(Accounts.Oidc.User, sub: sub)
  end

  def get_or_create_user_with_oidc(
        %{
          sub: sub
        } = attrs
      ) do
    case get_oidc_user_by_sub(sub) do
      nil -> create_new_user(attrs)
      %Accounts.Oidc.User{} = user -> update_oidc_user(user, attrs)
    end
  end

  defp create_new_user(attrs) do
    with {:ok, claper_user} <- get_user_by_email_or_create(attrs.email),
         updated_attrs <-
           Map.merge(attrs, %{user_id: claper_user.id}),
         {:ok, user} <- create_oidc_user(updated_attrs) do
      {:ok, user |> Repo.preload(:user)}
    else
      _ -> {:error, %{reason: :invalid_user, msg: "Invalid Claper user"}}
    end
  end

  defp update_oidc_user(user, attrs) do
    user
    |> Accounts.Oidc.User.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, user} -> {:ok, user |> Repo.preload(:user)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  ## Role Management

  @doc """
  Returns the list of roles.

  ## Examples

      iex> list_roles()
      [%Role{}, ...]

  """
  def list_roles do
    Repo.all(Role)
  end

  @doc """
  Gets a single role.

  Raises `Ecto.NoResultsError` if the Role does not exist.

  ## Examples

      iex> get_role!(123)
      %Role{}

      iex> get_role!(456)
      ** (Ecto.NoResultsError)

  """
  def get_role!(id), do: Repo.get!(Role, id)

  @doc """
  Gets a role by name.

  Returns nil if the Role does not exist.

  ## Examples

      iex> get_role_by_name("admin")
      %Role{}

      iex> get_role_by_name("nonexistent")
      nil

  """
  def get_role_by_name(name) when is_binary(name) do
    Repo.get_by(Role, name: name)
  end

  @doc """
  Creates a role.

  ## Examples

      iex> create_role(%{field: value})
      {:ok, %Role{}}

      iex> create_role(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a role.

  ## Examples

      iex> update_role(role, %{field: new_value})
      {:ok, %Role{}}

      iex> update_role(role, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_role(%Role{} = role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a role.

  ## Examples

      iex> delete_role(role)
      {:ok, %Role{}}

      iex> delete_role(role)
      {:error, %Ecto.Changeset{}}

  """
  def delete_role(%Role{} = role) do
    Repo.delete(role)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking role changes.

  ## Examples

      iex> change_role(role)
      %Ecto.Changeset{data: %Role{}}

  """
  def change_role(%Role{} = role, attrs \\ %{}) do
    Role.changeset(role, attrs)
  end

  @doc """
  Assigns a role to a user by role name or role struct.

  ## Examples

      iex> assign_role(user, "admin")
      {:ok, %User{}}

      iex> assign_role(user, %Role{id: 1})
      {:ok, %User{}}

      iex> assign_role(user, "unknown")
      {:error, :role_not_found}
  """
  def assign_role(%User{} = user, %Role{} = role) do
    user
    |> Ecto.Changeset.change(%{role_id: role.id})
    |> Repo.update()
  end

  def assign_role(%User{} = user, role_name) when is_binary(role_name) do
    case get_role_by_name(role_name) do
      nil ->
        {:error, :role_not_found}

      role ->
        user
        |> Ecto.Changeset.change(%{role_id: role.id})
        |> Repo.update()
    end
  end

  @doc """
  Gets the role of a user.

  ## Examples

      iex> get_user_role(user)
      %Role{}

      iex> get_user_role(user_without_role)
      nil
  """
  def get_user_role(%User{} = user) do
    user = user |> Repo.preload(:role)
    user.role
  end

  @doc """
  Lists users by role name.

  ## Examples

      iex> list_users_by_role("admin")
      [%User{}, ...]

      iex> list_users_by_role("unknown")
      []
  """
  def list_users_by_role(role_name) when is_binary(role_name) do
    case get_role_by_name(role_name) do
      nil ->
        []

      role ->
        User
        |> where([u], u.role_id == ^role.id and is_nil(u.deleted_at))
        |> Repo.all()
    end
  end

  @doc """
  Checks if a user has a specific role.

  ## Examples

      iex> user_has_role?(user, "admin")
      true

      iex> user_has_role?(user, "unknown")
      false
  """
  def user_has_role?(%User{} = user, role_name) when is_binary(role_name) do
    case get_user_role(user) do
      nil -> false
      role -> role.name == role_name
    end
  end

  @doc """
  Promotes a user to admin role.

  ## Examples

      iex> promote_to_admin(user)
      {:ok, %User{}}

      iex> promote_to_admin(already_admin_user)
      {:ok, %User{}}
  """
  def promote_to_admin(%User{} = user) do
    assign_role(user, "admin")
  end

  @doc """
  Demotes a user from admin role to regular user role.

  ## Examples

      iex> demote_from_admin(admin_user)
      {:ok, %User{}}

      iex> demote_from_admin(already_user_user)
      {:ok, %User{}}
  """
  def demote_from_admin(%User{} = user) do
    assign_role(user, "user")
  end

  # Private helper to set default role if not already set
  defp maybe_set_default_role(attrs) do
    # Only set default role if role_id is not explicitly provided
    case Map.get(attrs, :role_id) || Map.get(attrs, "role_id") do
      nil -> set_default_user_role(attrs)
      _ -> attrs
    end
  end

  defp set_default_user_role(attrs) do
    case get_role_by_name("user") do
      nil -> attrs
      user_role -> put_role_id(attrs, user_role.id)
    end
  end

  defp put_role_id(attrs, role_id) do
    key = determine_role_key(attrs)
    Map.put(attrs, key, role_id)
  end

  defp determine_role_key(attrs) do
    if has_string_keys?(attrs) do
      "role_id"
    else
      :role_id
    end
  end

  defp has_string_keys?(attrs) do
    is_map(attrs) and map_size(attrs) > 0 and
      Enum.all?(Map.keys(attrs), &is_binary/1)
  end
end
