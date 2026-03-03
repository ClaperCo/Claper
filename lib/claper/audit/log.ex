defmodule Claper.Audit.Log do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    max_limit: 100,
    filterable: [:action, :user_email],
    sortable: [:inserted_at, :action],
    default_order: %{
      order_by: [:inserted_at],
      order_directions: [:desc]
    },
    adapter_opts: [
      join_fields: [
        user_email: [
          binding: :user,
          field: :email,
          path: [:user, :email]
        ]
      ]
    ]
  }

  schema "audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :integer
    field :metadata, :map, default: %{}

    belongs_to :user, Claper.Accounts.User

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:action, :resource_type, :resource_id, :metadata, :user_id])
    |> validate_required([:action])
    |> validate_length(:action, max: 255)
    |> validate_length(:resource_type, max: 255)
    |> assoc_constraint(:user)
  end
end
