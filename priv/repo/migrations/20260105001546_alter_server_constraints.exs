defmodule ChatServer.Repo.Migrations.AlterServerConstraints do
  use Ecto.Migration

  def change do
    drop constraint(:server_users, "server_users_last_selected_channel_id_fkey")

    alter table(:server_users) do
      modify :last_selected_channel_id, references(:server_channels, on_delete: :nilify_all)
    end

    drop constraint(:server_users, "server_users_last_selected_channel_id_fkey")
  end
end
