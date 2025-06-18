defmodule ChatServer.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset

  schema "servers" do
    field :name, :string
    field :private, :boolean, default: false
    field :description, :string

    belongs_to :user, ChatServer.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(server, attrs) do
    server
    |> cast(attrs, [:name, :description, :private])
    |> validate_required([:name, :description, :private])
  end
end
