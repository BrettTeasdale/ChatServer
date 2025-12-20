defmodule ChatServer.Servers do
  @moduledoc """
  The Servers context.
  """

  import Ecto.Query, warn: false
  alias ChatServer.Servers.Channel
  alias ChatServer.Repo

  alias ChatServer.Servers
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


  def search_servers(query, amount) do
    query = from(
      s in Server,
      where: s.private == ^false and (ilike(s.name, ^"%#{query}%") or ilike(s.description, ^"%#{query}%")),
      order_by: [asc: s.id],
      limit: ^amount
    )

    Repo.all(query)
  end

  @doc """
  Returns the list of a user's owned and joined servers.

  ## Examples

      iex> list_user_servers()
      [%Server{}, ...]

  """
  def list_user_servers(user_id) when is_number(user_id) do
    from(su in ServerUser, where: su.user_id == ^user_id, preload: [:server])
    |> Repo.all()
  end

  @doc """
  Returns the list of a channel's latest messages

  ## Examples

      iex> list_latest_channel_messages($)
      [%Server{}, ...]

  """
  def list_latest_channel_messages(nil) do
    []
  end

@doc """
  Returns the list of a channel's latest messages

  ## Examples

      iex> list_latest_channel_messages($)
      [%Server{}, ...]

  """
  def list_latest_channel_messages(channel_id, limit) when is_number(channel_id) or is_binary(channel_id) do
    from(m in Message, where: m.channel_id == ^channel_id, preload: [:user], limit: ^limit, order_by: [desc: m.id])
    |> Repo.all()
    |> Enum.reverse()
  end

  def list_previous_channel_messages(channel_id, last_message_id, message_amount) do
    query = from(
      m in Message,
      where: m.channel_id == ^channel_id and m.id < ^last_message_id,
      preload: [:user],
      order_by: [desc: m.id],
      limit: ^message_amount
    )

    Repo.all(query)
  end

  def list_next_channel_messages(channel_id, last_message_id, message_amount) do
    query = from(
      m in Message,
      where: m.channel_id == ^channel_id and m.id > ^last_message_id,
      preload: [:user],
      order_by: [asc: m.id],
      limit: ^message_amount
    )

    Repo.all(query)
  end


  def list_previous_servers(query, last_server_id, page_size) do
    all_row_numbers = from(
      s in Server,
      select: %{id: s.id, row_number: row_number() |> over(order_by: s.name)},
      where: ilike(s.name, ^"%#{query}%") or ilike(s.description, ^"%#{query}%"),
      order_by: [asc: s.name]
    )

    single_row_number = with_cte(Server, "all_row_numbers", as: ^all_row_numbers)
    |> join(:inner, [s], rn in "all_row_numbers", on: rn.id == s.id)
    |> where([_s, rn], rn.id == ^last_server_id)
    |> select([s,rn], %{id: rn.id, row_number: rn.row_number})

    query = with_cte(Server, "all_row_numbers", as: ^all_row_numbers)
    |> with_cte("single_row_number", as: ^single_row_number)
    |> join(:inner, [s], rn in "all_row_numbers", on: rn.id == s.id)
    |> join(:left, [s, rn], srn in "single_row_number", on: true)
    |> where([s, rn, srn], rn.row_number < srn.row_number)
    |> select([s, _rn, _srn], s)
    |> order_by([s], [desc: s.name])
    |> limit(^page_size)

    Repo.all(query)
  end

  def list_next_servers(query, last_server_id, page_size) do
    all_row_numbers = from(
      s in Server,
      select: %{id: s.id, row_number: row_number() |> over(order_by: s.name)},
      where: ilike(s.name, ^"%#{query}%") or ilike(s.description, ^"%#{query}%"),
      order_by: [asc: s.name]
    )

    single_row_number = with_cte(Server, "all_row_numbers", as: ^all_row_numbers)
    |> join(:inner, [s], rn in "all_row_numbers", on: rn.id == s.id)
    |> where([_s, rn], rn.id == ^last_server_id)
    |> select([s,rn], %{id: rn.id, row_number: rn.row_number})

    query = with_cte(Server, "all_row_numbers", as: ^all_row_numbers)
    |> with_cte("single_row_number", as: ^single_row_number)
    |> join(:inner, [s], rn in "all_row_numbers", on: rn.id == s.id)
    |> join(:left, [s, rn], srn in "single_row_number", on: true)
    |> where([s, rn, srn], rn.row_number > srn.row_number)
    |> select([s, _rn, _srn], s)
    |> order_by([s], [asc: s.name])
    |> limit(^page_size)

    Repo.all(query)
  end

  def search_messages_in_server(query, amount) do
    query = from(
      m in Message,
      where: ilike(m.message, ^"%#{query}%"),
      preload: [:user, :channel],
      order_by: [desc: m.id],
      limit: ^amount
    )

    Repo.all(query)
  end


  def list_previous_search_messages(query, last_message_id, message_amount) do
    query = from(
      m in Message,
      where: m.id < ^last_message_id and ilike(m.message, ^"%#{query}%"),
      preload: [:user, :channel],
      order_by: [desc: m.id],
      limit: ^message_amount
    )

    Repo.all(query)
  end

  def list_next_search_messages(query, last_message_id, message_amount) do
    query = from(
      m in Message,
      where: m.id > ^last_message_id and ilike(m.message, ^"%#{query}%"),
      preload: [:user, :channel],
      order_by: [asc: m.id],
      limit: ^message_amount
    )

    Repo.all(query)
  end

  def list_channel_messages_from_message_id(message_id, message_amount) do
    channel_id = Repo.get!(Message, message_id).channel_id

    below = from(
      m in Message,
      where: m.channel_id == ^channel_id and m.id <= ^message_id,
      order_by: [desc: m.id],
      limit: ^message_amount
    )

    above = from(
      m in Message,
      where: m.channel_id == ^channel_id and m.id > ^message_id,
      preload: [:user, :channel],
      order_by: [asc: m.id],
      limit: ^message_amount
    )

    Repo.all(union(subquery(below), ^above))
  end



  def get_channel_top_message!(channel_id) do
    from(m in Message, where: m.channel_id == ^channel_id, order_by: [asc: m.inserted_at], limit: 1)
    |> Repo.one()
  end

  @doc """
  Returns the list of a channels a user belongs to.

  ## Examples

      iex> list_user_servers()
      [%Server{}, ...]

  """
  def list_server_user_channels(server_user_id) when is_nil(server_user_id) do
    []
  end

  def list_server_user_channels(server_id) when is_number(server_id) or is_binary(server_id) do
    from(c in Channel, where: c.server_id == ^server_id)
    |> Repo.all()
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
  def get_server_user!(server_user_id) when is_number(server_user_id) or is_binary(server_user_id) do
    Repo.get!(ServerUser, server_user_id)
    |> Repo.preload([:last_selected_channel, :server])
  end

  def get_server_default_channel!(server_id) when is_number(server_id) or is_binary(server_id) do
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
  def create_server(user_id, %{} = attrs) when is_number(user_id) or is_binary(user_id) do
    Repo.transaction(fn ->
      {:ok, server} = %Server{}
      |> Server.changeset(attrs)
      |> Repo.insert()

      {:ok, server_user} = %ServerUser{}
      |> ServerUser.changeset(%{
        user_id: user_id,
        server_id: server.id
      })
      |> Repo.insert()

        {:ok, default_channel} = Channel.changeset(%Channel{}, %{
          name: "General",
          private: false,
          is_default: true,
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

      server_user
    end)
  end

  def get_server_default_channel(server_id) do
    query = from(
      c in Channel,
      where: c.server_id == ^server_id and c.is_default == true
    )

    Repo.one!(query)
  end

  @doc """
  Creates a server that belongs to a user
  """
  def join_server(user_id, server_id) do
    server = Servers.get_server!(server_id)
    default_channel = Servers.get_server_default_channel!(server_id)

    {:ok, server_user} = %ServerUser{}
    |> ServerUser.changeset(%{
      user_id: user_id,
      server_id: server.id,
      last_selected_channel_id: default_channel.id
    })
    |> Repo.insert()

    server_user
  end

  def leave_server(user_id, server_id) do
    query = from(
      su in ServerUser,
      where: su.user_id == ^user_id and su.server_id == ^server_id
    )
    server_user = Repo.one(query)
    if server_user != nil, do: Repo.delete!(server_user)
  end

  @doc """
  Creates a channel that belongs to a server
  """
  def create_channel(server_id, %{} = attrs) do
    attrs = Map.put(attrs, "server_id", server_id)

    channel = %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()

    case channel do
      {:error, changeset} -> {:error, changeset}
      {:ok, channel} -> {:ok, Repo.preload(channel, :server)}
    end
  end

  @doc """
  Creates a message that belongs to a user
  """
  def create_message(user_id, channel_id, %{} = attrs) when (is_number(user_id) or is_binary(user_id)) and (is_number(channel_id) or is_binary(channel_id))do
    attrs = Map.put(attrs, "channel_id", channel_id)
    |> Map.put("user_id", user_id)

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
