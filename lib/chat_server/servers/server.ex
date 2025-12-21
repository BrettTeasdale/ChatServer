defmodule ChatServer.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset

  schema "servers" do
    field :name, :string
    field :private, :boolean, default: false
    field :description, :string
    field :full_text_search, :string

    has_many :server_users, ChatServer.Servers.ServerUser

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(server, attrs) do
    server
    |> cast(attrs, [:name, :description, :private])
    |> put_change(:full_text_search, "#{attrs["name"]} #{attrs["description"]}")
    |> validate_required([:name, :description, :private])
  end
end
