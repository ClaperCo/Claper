defmodule Claper.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Claper.Accounts
  alias Claper.Repo

  alias Claper.Accounts.{User, UserToken, UserNotifier}

  @doc """
  Creates a user.

  ## Examples
      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_user(attrs) do
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
    Repo.get_by(User, email: email)
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
        create_user(%{
          email: email,
          confirmed_at: DateTime.utc_now(),
          is_randomized_password: true,
          password: :crypto.strong_rand_bytes(32)
        })

      user ->
        {:ok, user}
    end
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
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
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

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
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
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
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

  def delete(user) do
    Repo.delete(user)
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
end
