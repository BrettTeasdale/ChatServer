defmodule ChatServer.Servers.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_channel_messages" do
    field :message, :string

    belongs_to :user, ChatServer.Accounts.User
    belongs_to :channel, ChatServer.Servers.Channel

    has_many :uploads, ChatServer.Servers.Upload

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:message, :user_id, :channel_id])
    |> validate_required([:message, :user_id, :channel_id])
  end
end
