defmodule Claper.Accounts.User do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  @derive {
    Flop.Schema,
    max_limit: 100,
    default_limit: 20,
    pagination_types: [:page],
    filterable: [:email, :first_name, :last_name, :role_id],
    sortable: [:email, :first_name, :last_name, :role_id, :confirmed_at, :inserted_at],
    default_order: %{
      order_by: [:inserted_at],
      order_directions: [:desc]
    }
  }

  @type t :: %__MODULE__{
          id: integer(),
          uuid: Ecto.UUID.t(),
          email: String.t(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          password: String.t() | nil,
          hashed_password: String.t(),
          is_randomized_password: boolean(),
          confirmed_at: NaiveDateTime.t() | nil,
          locale: String.t() | nil,
          events: [Claper.Events.Event.t()] | nil,
          role: Claper.Accounts.Role.t() | nil,
          role_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t(),
          deleted_at: NaiveDateTime.t() | nil
        }

  schema "users" do
    field :uuid, :binary_id
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :is_randomized_password, :boolean
    field :confirmed_at, :naive_datetime
    field :locale, :string
    field :deleted_at, :naive_datetime

    has_many :events, Claper.Events.Event
    has_one :lti_user, Lti13.Users.User
    belongs_to :role, Claper.Accounts.Role
    has_many :quiz_responses, Claper.Quizzes.QuizResponse

    timestamps()
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :email,
      :first_name,
      :last_name,
      :confirmed_at,
      :password,
      :is_randomized_password,
      :role_id
    ])
    |> normalize_names()
    |> validate_email()
    |> validate_names(Keyword.get(opts, :require_names, true))
    |> validate_confirmation(:password)
    |> validate_password(opts)
    |> foreign_key_constraint(:role_id)
  end

  def preferences_changeset(user, attrs) do
    user
    |> cast(attrs, [:locale])
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name])
    |> normalize_names()
    |> validate_names(true)
  end

  def external_profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name])
    |> normalize_names()
    |> validate_names(false)
  end

  def display_name(%__MODULE__{} = user) do
    [user.first_name, user.last_name]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> user.email
      name -> name
    end
  end

  @doc """
  A changeset for admin operations on users.
  """
  def admin_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :first_name, :last_name, :confirmed_at, :password, :role_id])
    |> normalize_names()
    |> validate_email()
    |> validate_names(Keyword.get(opts, :require_names, false))
    |> validate_admin_password(opts)
    |> foreign_key_constraint(:role_id)
  end

  @doc """
  A changeset for marking a user as deleted.
  """
  def delete_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, deleted_at: now)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Claper.Repo,
      query: from(user in __MODULE__, where: is_nil(user.deleted_at))
    )
    |> unique_constraint(:email)
  end

  defp normalize_names(changeset) do
    changeset
    |> update_change(:first_name, &normalize_name/1)
    |> update_change(:last_name, &normalize_name/1)
  end

  defp normalize_name(name) when is_binary(name), do: String.trim(name)
  defp normalize_name(name), do: name

  defp validate_names(changeset, require_names?) do
    changeset =
      changeset
      |> validate_length(:first_name, max: 160)
      |> validate_length(:last_name, max: 160)

    if require_names? do
      validate_required(changeset, [:first_name, :last_name])
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 72)
    |> maybe_hash_password(opts)
  end

  defp validate_admin_password(changeset, opts) do
    password = get_change(changeset, :password)

    # Only validate password if it's provided
    if password && password != "" do
      changeset
      |> validate_length(:password, min: 6, max: 72)
      |> maybe_hash_password(opts)
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password, :is_randomized_password])
    |> validate_confirmation(:password)
    |> validate_password(opts)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Claper.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
