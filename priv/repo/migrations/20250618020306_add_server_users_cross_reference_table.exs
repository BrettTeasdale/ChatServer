defmodule ChatServer.Repo.Migrations.AddServerUsersCrossReferenceTable do
  use Ecto.Migration

  def change do
    create table(:server_users) do
      add :server_id, references(:servers)
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:server_users, [:server_id])
    create index(:server_users, [:user_id])
  end
end
