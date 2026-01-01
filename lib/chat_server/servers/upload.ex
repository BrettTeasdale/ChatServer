defmodule ChatServer.Servers.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_channel_message_uploads" do
    field :filename, :string
    field :mime, :string

    belongs_to :message, ChatServer.Servers.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(upload, attrs) do
    upload
    |> cast(attrs, [:mime, :filename])
    |> validate_required([:mime, :filename])
  end
end
