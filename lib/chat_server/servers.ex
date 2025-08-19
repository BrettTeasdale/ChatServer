defmodule ChatServer.Servers do
  @moduledoc """
  The Servers context.
  """

  import Ecto.Query, warn: false
  alias ChatServer.Servers.Channel
  alias ChatServer.Repo

  alias ChatServer.Servers.Server
  alias ChatServer.Servers.ServerUser
  alias ChatServer.Servers.Channel
  alias ChatServer.Servers.Message
  alias ChatServer.Accounts.User

  def server_list_topic(user_id) do
    "server_list:#{user_id}"
  end

  def server_list_subscribe(user_id) do
    Phoenix.PubSub.subscribe(ChatServer.PubSub, server_list_topic(user_id))
  end

  def server_list_broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(ChatServer.PubSub, server_list_topic(user_id), message)
  end


  def channel_list_topic(user_id, server_id) do
    "channel_list:#{user_id}:#{server_id}"
  end

  def channel_list_subscribe(user_id, server_id) do
    Phoenix.PubSub.subscribe(ChatServer.PubSub, channel_list_topic(user_id, server_id))
  end

  def channel_list_unsubscribe(user_id, server_id) do
    Phoenix.PubSub.unsubscribe(ChatServer.PubSub, channel_list_topic(user_id, server_id))
  end

  def channel_list_broadcast(user_id, server_id, message) do
    Phoenix.PubSub.broadcast(ChatServer.PubSub, channel_list_topic(user_id, server_id), message)
  end


  def chat_topic(channel_id) do
    "channel:#{channel_id}"
  end

  def chat_subscribe(channel_id) do
    Phoenix.PubSub.subscribe(ChatServer.PubSub, chat_topic(channel_id))
  end

  def chat_unsubscribe(channel_id) do
    Phoenix.PubSub.unsubscribe(ChatServer.PubSub, chat_topic(channel_id))
  end

  def chat_broadcast(channel_id, message) do
    Phoenix.PubSub.broadcast(ChatServer.PubSub, chat_topic(channel_id), message)
  end

  @doc """
  Returns the list of servers.

  ## Examples

      iex> list_servers()
      [%Server{}, ...]

  """
  def list_servers do
    Repo.all(Server)
  end

  @doc """
  Returns the list of a user's owned and joined servers.

  ## Examples

      iex> list_user_servers()
      [%Server{}, ...]

  """
  def list_user_servers(%User{} = user) do
    from(su in ServerUser, where: su.user_id == ^user.id, preload: [:server])
    |> Repo.all()
  end

  @doc """
  Returns the list of a channel's latest messages

  ## Examples

      iex> list_latest_channel_messages($)
      [%Server{}, ...]

  """
  def list_latest_channel_messages(%Channel{id: nil}) do
    []
  end

@doc """
  Returns the list of a channel's latest messages

  ## Examples

      iex> list_latest_channel_messages($)
      [%Server{}, ...]

  """
  def list_latest_channel_messages(%Channel{} = channel) do
    from(m in Message, where: m.channel_id == ^channel.id, preload: [:user], limit: ^100)
    |> Repo.all()
  end

  @doc """
  Returns the list of a channels a user belongs to.

  ## Examples

      iex> list_user_servers()
      [%Server{}, ...]

  """
  def list_server_user_channels(%ServerUser{id: id}) when is_nil(id) do
    []
  end

  def list_server_user_channels(server_id) when is_binary(server_id) do
    # No need to pass whole structs around, the id's are smaller
    Repo.all(
      from c in Channel,
      where: c.server_id == ^server_id
    )
  end

  @doc """
  Gets a single server user record.

  Raises `Ecto.NoResultsError` if the ServerUser does not exist.

  ## Examples

      iex> get_server_user!(123)
      %ServerUser{}

      iex> get_server!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_user!(server_user_id) do
    Repo.get!(ServerUser, server_user_id)
    |> Repo.preload(:last_selected_channel)
    |> Repo.preload(:server)
  end

  def get_server_default_channel!(server_id) do
    from(c in Channel, where: c.server_id == ^server_id and c.is_default == true)
    |> first()
    |> Repo.one!()
  end


  def get_channel!(channel_id) do
    Repo.get!(Channel, channel_id)
  end

  @doc """
  Gets a single server.

  Raises `Ecto.NoResultsError` if the Server does not exist.

  ## Examples

      iex> get_server!(123)
      %Server{}

      iex> get_server!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server!(id), do: Repo.get!(Server, id)


  @doc """
  Creates a server that belongs to a user
  """
  def create_server(%User{} = user, %{} = attrs) do
    Repo.transaction(fn ->
      {:ok, server} = %Server{}
      |> Server.changeset(attrs)
      |> Repo.insert()

      {:ok, server_user} = %ServerUser{}
      |> ServerUser.changeset(%{
        user_id: user.id,
        server_id: server.id
      })
      |> Repo.insert()

        {:ok, default_channel} = Channel.changeset(%Channel{}, %{
          name: "General",
          private: false,
          description: "A channel for general discussions.",
          server_id: server_user.server_id
      })
      |> Repo.insert()

      {:ok, server_user} = ServerUser.changeset(server_user, %{
        last_selected_channel_id: default_channel.id,
      })
      |> Repo.update()

      server_user = server_user
      |> Repo.preload(:user)
      |> Repo.preload(:server)

      IO.inspect(server_user)

      server_user
    end)
  end

  @doc """
  Creates a channel that belongs to a server
  """
  def create_channel(%ServerUser{} = server_user, %{} = attrs) do
    attrs = Map.put(attrs, "server_id", server_user.server_id)

    {:ok, channel} = %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()

    {:ok, Repo.preload(channel, :server)}
  end

  @doc """
  Creates a message that belongs to a user
  """
  def create_message(%User{} = user, %Channel{} = channel, %{} = attrs) do
    attrs = Map.put(attrs, "channel_id", channel.id)
    |> Map.put("user_id", user.id)

    {:ok, message} = %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()

    message = message
    |> Repo.preload(:user)
    |> Repo.preload(:channel)

    {:ok, message}
  end

  @doc """
  Creates a server.

  ## Examples

      iex> create_server(%{field: value})
      {:ok, %Server{}}

      iex> create_server(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server(%{} = attrs) when not is_struct(attrs, User) do
    %Server{}
    |> Server.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a server.

  ## Examples

      iex> update_server(server, %{field: new_value})
      {:ok, %Server{}}

      iex> update_server(server, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server(%Server{} = server, attrs) do
    server
    |> Server.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a server.

  ## Examples

      iex> delete_server(server)
      {:ok, %Server{}}

      iex> delete_server(server)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server(%Server{} = server) do
    Repo.delete(server)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server changes.

  ## Examples

      iex> change_server(server)
      %Ecto.Changeset{data: %Server{}}

  """
  def change_server(%Server{} = server, attrs \\ %{}) do
    Server.changeset(server, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server changes.

  ## Examples

      iex> change_channel(server)
      %Ecto.Changeset{data: %Server{}}

  """
  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end
end
