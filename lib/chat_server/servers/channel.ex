defmodule ChatServer.Servers.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_channels" do
    field :name, :string
    field :needs_owner, :boolean, default: false
    field :needs_operator, :boolean, default: false
    field :needs_voiced, :boolean, default: false
    field :is_default, :boolean, default: false
    field :description, :string

    belongs_to :server, ChatServer.Servers.Server

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :name,
      :server_id,
      :description,
      :needs_owner,
      :needs_operator,
      :needs_voiced,
      :is_default
    ])
    |> validate_required([:name, :description, :server_id])
  end
end
