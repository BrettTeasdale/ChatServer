defmodule ChatServer.Repo.Migrations.CreateServerChannelMessageUploads do
  use Ecto.Migration

  def change do
    create table(:server_channel_message_uploads) do
      add :mime, :string
      add :filename, :string
      add :message_id, references(:server_channel_messages, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:server_channel_message_uploads, [:message_id])
  end
end
