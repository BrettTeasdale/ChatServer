defmodule ChatServer.Repo.Migrations.CreateServers do
  use Ecto.Migration

  def change do
    create table(:servers) do
      add :name, :string
      add :description, :text
      add :private, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:servers, [:user_id])
  end
end
