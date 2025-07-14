defmodule ChatServer.Repo.Migrations.AddPermissionsToChannels do
  use Ecto.Migration

  def change do
    alter table(:server_channels) do
      add :needs_owner, :boolean, default: false, null: false
      add :needs_operator, :boolean, default: false, null: false
      add :needs_voiced, :boolean, default: false, null: false

      remove :private
    end
  end
end
