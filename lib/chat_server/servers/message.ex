defmodule ChatServer.Servers.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_channel_messages" do
    field :message, :string
    field :user_id, :id
    field :channel_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:message])
    |> validate_required([:message])
  end
end
