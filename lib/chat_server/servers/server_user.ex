defmodule ChatServer.Servers.ServerUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_users" do
    belongs_to :server, ChatServer.Servers.Server
    belongs_to :user, ChatServer.Accounts.User
    belongs_to :last_selected_channel, ChatServer.Servers.Channel

    timestamps()
  end


  @doc false
  def changeset(server_user, attrs) do
    server_user
    |> cast(attrs, [:user_id, :server_id, :last_selected_channel_id])
    |> validate_required([:user_id, :server_id])
  end
end
