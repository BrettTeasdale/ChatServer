defmodule ChatServer.Repo.Migrations.CreateServerChannelMessages do
  use Ecto.Migration

  def change do
    create table(:server_channel_messages) do
      add :message, :text
      add :user_id, references(:users, on_delete: :nothing)
      add :channel_id, references(:server_channels, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:server_channel_messages, [:user_id])
    create index(:server_channel_messages, [:channel_id])
  end
end
