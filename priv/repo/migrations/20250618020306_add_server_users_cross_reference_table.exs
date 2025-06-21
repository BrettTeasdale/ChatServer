defmodule ChatServer.Repo.Migrations.AddServerUsersCrossReferenceTable do
  use Ecto.Migration

  def change do
    create table(:server_users) do
      add :server_id, references(:servers)
      add :user_id, references(:users, on_delete: :nothing)

      add :owner, :boolean
      add :operator, :boolean
      add :voiced, :boolean

      timestamps(type: :utc_datetime)
    end

    create index(:server_users, [:server_id])
    create index(:server_users, [:user_id])
    create index(:server_users, [:owner])
    create index(:server_users, [:operator])
    create index(:server_users, [:voiced])
  end
end
