defmodule Claper.Events.Folder do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          uuid: Ecto.UUID.t(),
          name: String.t() | nil,
          user: Claper.Accounts.User.t() | nil,
          parent: t() | nil,
          children: [t()] | nil,
          events: [Claper.Events.Event.t()] | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "folders" do
    field :uuid, :binary_id
    field :name, :string

    belongs_to :user, Claper.Accounts.User
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :events, Claper.Events.Event

    timestamps()
  end

  @doc false
  def changeset(folder, attrs) do
    folder
    |> cast(attrs, [:name, :user_id, :parent_id])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_name_fits_url()
    |> unique_constraint(:name, name: :folders_root_name_index)
    |> unique_constraint(:name, name: :folders_parent_name_index)
    |> maybe_put_uuid()
  end

  # Folder names are used as URL path segments
  defp validate_name_fits_url(changeset) do
    validate_change(changeset, :name, fn :name, name ->
      if String.contains?(name, "/") or name in [".", ".."],
        do: [name: "cannot contain / or be . or .."],
        else: []
    end)
  end

  defp maybe_put_uuid(%Ecto.Changeset{data: %{uuid: nil}} = changeset),
    do: put_change(changeset, :uuid, Ecto.UUID.generate())

  defp maybe_put_uuid(changeset), do: changeset
end
