defmodule Claper.Events.ActivityLeader do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_leaders" do
    field :temp_id, :string, virtual: true
    field :delete, :boolean, virtual: true

    field :user_id, :integer, virtual: true
    field :user_email, :string, virtual: true

    field :email, :string
    belongs_to :event, Claper.Events.Event

    timestamps()
  end

  @doc false
  def changeset(leader, attrs) do
    leader
    |> Map.put(:temp_id, leader.temp_id || attrs["temp_id"])
    |> cast(attrs, [
      :email,
      :event_id,
      :delete,
      :user_email
    ])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, min: 6, max: 160)
    |> unique_constraint(:email)
    |> validate_not_current_user_email
    |> unsafe_validate_unique([:event_id, :email], Claper.Repo)
    |> maybe_mark_for_deletion
  end

  defp maybe_mark_for_deletion(%{data: %{id: nil}} = changeset), do: changeset

  defp maybe_mark_for_deletion(changeset) do
    if get_change(changeset, :delete) do
      %{changeset | action: :delete}
    else
      changeset
    end
  end

  defp validate_not_current_user_email(changeset) do
    email = get_field(changeset, :email)
    user_email = get_change(changeset, :user_email)

    if email == user_email do
      add_error(changeset, :email, "cannot be the same as the current user's email")
    else
      changeset
    end
  end
end
