defmodule ChatServer.Servers.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_channels" do
    field :name, :string
    field :private, :boolean, default: false
    field :description, :string

    belongs_to :server, ChatServer.Servers.Server

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :description, :private])
    |> validate_required([:name, :description, :private])
  end
end
