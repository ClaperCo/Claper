defmodule Claper.Repo.Migrations.CreateFolders do
  use Ecto.Migration

  def change do
    create table(:folders) do
      add :uuid, :binary_id, null: false, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :parent_id, references(:folders, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:folders, [:uuid])
    create index(:folders, [:user_id])
    create index(:folders, [:parent_id])

    # Names are unique among siblings. NULLs are distinct in a plain unique index,
    # so top-level folders get their own partial index.
    create unique_index(:folders, [:user_id, :name],
             where: "parent_id IS NULL",
             name: :folders_root_name_index
           )

    create unique_index(:folders, [:parent_id, :name],
             where: "parent_id IS NOT NULL",
             name: :folders_parent_name_index
           )

    alter table(:events) do
      add :folder_id, references(:folders, on_delete: :nilify_all)
    end

    create index(:events, [:folder_id])
  end
end
