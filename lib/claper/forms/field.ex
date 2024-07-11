defmodule Claper.Forms.Field do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
        }

  @primary_key false
  embedded_schema do
    field :name, :string
    field :type, :string
  end

  @doc false
  def changeset(form, attrs \\ %{}) do
    form
    |> cast(attrs, [:name, :type])
    |> validate_required([:name, :type])
  end
end
