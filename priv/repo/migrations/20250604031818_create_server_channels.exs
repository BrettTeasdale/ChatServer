defmodule ChatServer.Repo.Migrations.CreateServerChannels do
  use Ecto.Migration

  def change do
    create table(:server_channels) do
      add :name, :string
      add :description, :text
      add :private, :boolean, default: false, null: false
      add :is_default, :boolean, default: false, null: false
      add :server_id, references(:servers, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:server_channels, [:server_id])
  end
end
