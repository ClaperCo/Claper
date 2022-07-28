defmodule Claper.Accounts.User do
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field :uuid, :binary_id
    field :email, :string
    field :is_admin, :boolean
    field :confirmed_at, :naive_datetime

    has_many :events, Claper.Events.Event

    timestamps()
  end

  def registration_changeset(user, attrs, _opts \\ []) do
    user
    |> cast(attrs, [:email, :confirmed_at])
    |> validate_email()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Claper.Repo)
    |> unique_constraint(:email)
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
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

end
