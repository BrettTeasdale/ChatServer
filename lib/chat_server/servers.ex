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
  Returns the list of a channels a user belongs to.

  ## Examples

      iex> list_server_user_channels()
      [%Channel{}, ...]

  """
  def list_users_belonging_to_server(server_id) when is_number(server_id) or is_binary(server_id) do
    from(
      u in User,
      join: su in ServerUser, on: su.user_id == u.id,
      where: su.server_id == ^server_id,
      order_by: [asc: u.username]
    )
    |> Repo.all()
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
  Returns a paginated list of servers matching the search query.

  ## Examples

      iex> search_servers("query", 10)
      [%Server{}, ...]

  """
  def search_servers(query, amount) do
    query = from(
      s in Server,
      where: fragment("? <@> to_bm25query(?, 'servers_full_text_search_bm25') < 0.75", s.full_text_search, ^query),
      order_by: [asc: fragment("? <@> to_bm25query(?, 'servers_full_text_search_bm25') ", s.full_text_search, ^query)],
      limit: ^amount
    )

    Repo.all(query)
  end

  @doc """
  Returns the previous page of a paginated list of servers matching the search query.

  ## Examples

      iex> search_servers("query", 10)
      [%Server{}, ...]

  """
  def search_servers_previous(query, last_server_id, page_size) do
    all_row_numbers = from(
      s in Server,
      select: %{id: s.id, row_number: row_number() |> over(order_by: fragment("? <@> to_bm25query(?, 'servers_full_text_search_bm25') ", s.full_text_search, ^query))},
      where: fragment("? <@> to_bm25query(?, 'servers_full_text_search_bm25') < 0.75", s.full_text_search, ^query),
      order_by: [asc: fragment("? <@> to_bm25query(?, 'servers_full_text_search_bm25') ", s.full_text_search, ^query)],
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

  @doc """
  Returns the next page of a paginated list of servers matching the search query.

  ## Examples

      iex> search_servers("query", 10)
      [%Server{}, ...]

  """
  def search_servers_next(query, last_server_id, page_size) do
    all_row_numbers = from(
      s in Server,
      select: %{id: s.id, row_number: row_number() |> over(order_by: fragment("? <@> to_bm25query(?, 'servers_full_text_search_bm25') ", s.full_text_search, ^query))},
      where: fragment("? <@> to_bm25query(?, 'servers_full_text_search_bm25') < 0.75", s.full_text_search, ^query),
      order_by: [asc: fragment("? <@> to_bm25query(?, 'servers_full_text_search_bm25') ", s.full_text_search, ^query)],
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
    |> order_by([s], [asc: fragment("? <@> to_bm25query(?, 'servers_full_text_search_bm25') ", s.full_text_search, ^query)])
    |> limit(^page_size)

    Repo.all(query)
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
  def delete_server(server_id) when is_number(server_id) or is_binary(server_id) do
    from(
      m in Message,
      join: c in Channel, on: c.id == m.channel_id,
      where: c.server_id == ^server_id
    )
    |> Repo.delete_all()

    from(
      c in Channel,
      where: c.server_id == ^server_id
    )
    |> Repo.delete_all()

    from(
      su in ServerUser,
      where: su.server_id == ^server_id
    )
    |> Repo.delete_all()

    from(
      s in Server,
      where: s.id == ^server_id
    )
    |> Repo.delete_all()
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
  Returns the list of a user's owned and joined servers.

  ## Examples

      iex> list_user_server_users()
      [%ServerUser{}, ...]

  """
  def list_user_server_users(user_id) when is_number(user_id) do
    from(
      su in ServerUser,
      join: s in Server, on: s.id == su.server_id,
      where: su.user_id == ^user_id,
      preload: [:server],
      order_by: [asc: s.name]
    )
    |> Repo.all()
  end


  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the Server does not exist.

   ## Examples

      iex> get_message!(123)
      %Server{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(id, preload \\ []) do
    Repo.get!(Message, id)
    |> Repo.preload(preload)
  end

  @doc """
  Returns the list of a channel's latest messages

  ## Examples

      iex> list_latest_channel_messages($)
      [%Message{}, ...]

  """
  def list_latest_channel_messages(nil) do
    []
  end

  @doc """
  Returns the list of a channel's latest messages

  ## Examples

      iex> list_latest_channel_messages($)
      [%Message{}, ...]

  """
  def list_latest_channel_messages(channel_id, limit) when is_number(channel_id) or is_binary(channel_id) do
    from(m in Message, where: m.channel_id == ^channel_id, preload: [:user], limit: ^limit, order_by: [desc: m.id])
    |> Repo.all()
    |> Enum.reverse()
  end


  @doc """
  Returns the list of a channel's around a specific message ID

  ## Examples

      iex> list_channel_messages_from_message_id(123, 10)
      [%Message{}, ...]

  """
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
      order_by: [asc: m.id],
      limit: ^message_amount
    )

    union = from(
      m in subquery(union(subquery(below), ^above)),
      order_by: [asc: m.id],
      preload: [:user, :channel],
      limit: ^message_amount
    )

    Repo.all(union)
  end

  @doc """
  Returns the previous page of a channel's paginated messages from a specific message ID

  ## Examples

      iex> list_channel_messages_previous(1, 123, 10)
      [%Message{}, ...]

  """
  def list_channel_messages_previous(channel_id, last_message_id, message_amount) do
    query = from(
      m in Message,
      where: m.channel_id == ^channel_id and m.id < ^last_message_id,
      preload: [:user],
      order_by: [desc: m.id],
      limit: ^message_amount
    )

    Repo.all(query)
  end

  @doc """
  Returns the next page of a channel's paginated messages from a specific message ID

  ## Examples

      iex> list_channel_messages_next(1, 123, 10)
      [%Message{}, ...]

  """
  def list_channel_messages_next(channel_id, last_message_id, message_amount) do
    query = from(
      m in Message,
      where: m.channel_id == ^channel_id and m.id > ^last_message_id,
      preload: [:user],
      order_by: [asc: m.id],
      limit: ^message_amount
    )

    Repo.all(query)
  end

  @doc """
  Returns the list of a channel's around a specific message ID

  ## Examples

      iex> list_channel_messages_from_message_id(123, 10)
      [%Message{}, ...]

  """
  def get_channel_first_message(channel_id) do
    from(
      m in Message,
      where: m.channel_id == ^channel_id,
      preload: [:user, :channel],
      order_by: [asc: m.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Returns a paginated list of messages matching the search query.

  ## Examples

      iex> search_messages("query", 10)
      [%Message{}, ...]

  """
  def search_messages(query, amount) do
    query = from(
      m in Message,
      where: fragment("? <@> to_bm25query(?, 'messages_full_text_search_bm25') < -1.0", m.message, ^query),
      preload: [:user, :channel],
      order_by: [desc: m.id],
      limit: ^amount
    )

    Repo.all(query)
  end


  @doc """
  Returns the previous page a paginated list of messages matching the search query.

  ## Examples

      iex> search_messages_previous("query", 10, 10)
      [%Message{}, ...]

  """
  def search_messages_previous(query, last_message_id, message_amount) do
    query = from(
      m in Message,
      where: m.id < ^last_message_id and (fragment("? <@> to_bm25query(?, 'messages_full_text_search_bm25') < -1.0", m.message, ^query)),
      preload: [:user, :channel],
      order_by: [desc: m.id],
      limit: ^message_amount
    )

    Repo.all(query)
  end

  @doc """
  Returns the next page a paginated list of messages matching the search query.

  ## Examples

      iex> search_messages_next("query", 10, 10)
      [%Message{}, ...]

  """
  def search_messages_next(query, last_message_id, message_amount) do
    query = from(
      m in Message,
      where: m.id > ^last_message_id and (fragment("? <@> to_bm25query(?, 'messages_full_text_search_bm25') < -1.0", m.message, ^query)),
      preload: [:user, :channel],
      order_by: [asc: m.id],
      limit: ^message_amount
    )

    Repo.all(query)
  end

  @doc """
  Gets a single server user record.

  Raises `Ecto.NoResultsError` if the ServerUser does not exist.

  ## Examples

      iex> get_server_user!(123)
      %ServerUser{}

      iex> get_server_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_user!(server_user_id) when is_number(server_user_id) or is_binary(server_user_id) do
    Repo.get!(ServerUser, server_user_id)
    |> Repo.preload([:last_selected_channel, :server])
  end


  @doc """
  Gets a single server user record.

  Raises `Ecto.NoResultsError` if the ServerUser does not exist.

  ## Examples

      iex> get_server_user!(123)
      %ServerUser{}

      iex> get_server_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_user_by_server_and_user!(server_user_id, user_id) when (is_number(server_user_id) or is_binary(server_user_id)) and (is_number(user_id) or is_binary(user_id)) do
    from(
      su in ServerUser,
      where: su.server_id == ^server_user_id and su.user_id == ^user_id,
      preload: [:server]
    )
    |> Repo.one!()
  end

  @doc """
  Create a ServerUser record when a user joins a server.

  ## Examples

      iex> join_server(123, 456)
      %ServerUser{}
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
    |> Repo.preload(:server)
  end

  @doc """
  Delete the corresponding ServerUser record when a user leaves a server.
  """
  def leave_server(user_id, server_id) do
    query = from(
      su in ServerUser,
      where: su.user_id == ^user_id and su.server_id == ^server_id
    )
    server_user = Repo.one(query)
    if server_user != nil, do: Repo.delete!(server_user)
  end

  @doc """
  Gets a single channel record.

  Raises `Ecto.NoResultsError` if the Channel does not exist.

  ## Examples

      iex> get_channel!(123)
      %Channel{}

      iex> get_channel!(456)
      ** (Ecto.NoResultsError)

  """
  def get_channel!(channel_id) do
    Repo.get!(Channel, channel_id)
  end


  @doc """
  Returns the list of a channels a user belongs to.

  ## Examples

      iex> list_server_user_channels()
      [%Channel{}, ...]

  """
  def list_server_user_channels(server_id) when is_number(server_id) or is_binary(server_id) do
    from(c in Channel, where: c.server_id == ^server_id)
    |> Repo.all()
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
  Creates a channel.

  ## Examples

      iex> create_channel(%{field: value})
      {:ok, %Server{}}

      iex> create_channel(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_channel(%{} = attrs) when not is_struct(attrs, User) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a channel.

  ## Examples

      iex> update_channel(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_channel(channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a channel.

  ## Examples

      iex> delete_channel(channel)
      {:ok, %Channel{}}

      iex> delete_channel(channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_channel(channel_id) when is_number(channel_id) or is_binary(channel_id) do
    Repo.delete_all(from(m in Message, where: m.channel_id == ^channel_id))
    Repo.delete_all(from(c in Channel, where: c.id == ^channel_id))
  end

  @doc """
  Deletes a channel.

  ## Examples

      iex> delete_channel(channel)
      {:ok, %Channel{}}

      iex> delete_channel(channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete_all(from(m in Message, where: m.channel_id == ^channel.id))
    Repo.delete(channel)
  end

  @doc """
  Gets a single server record.

  Raises `Ecto.NoResultsError` if the Server does not exist.

  ## Examples

      iex> get_server_default_channel!(123)
      %Channel{}

      iex> get_server_default_channel!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_default_channel!(server_id) when is_number(server_id) or is_binary(server_id) do
    from(c in Channel, where: c.server_id == ^server_id and c.is_default == true)
    |> first()
    |> Repo.one!()
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
    |> Repo.preload([:user, :channel])

    {:ok, message}
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
