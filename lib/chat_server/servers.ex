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
  Returns the list of a channels a user belongs to.

  ## Examples

      iex> list_user_servers()
      [%Server{}, ...]

  """
  def list_server_user_channels(%ServerUser{id: id}) when is_nil(id) do
    []
  end

  def list_server_user_channels(%ServerUser{} = server_user) do
    IO.inspect(server_user)
    from(c in Channel, where: c.server_id == ^server_user.server_id)
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
    # Repo.transaction(fn ->
    #   {:ok, server} = %Server{}
    #   |> Server.changeset(attrs)
    #   |> Repo.insert()

    #   {:ok, server_user} = %ServerUser{}
    #   |> ServerUser.changeset(%{
    #     user_id: user.id,
    #     server_id: server.id
    #   })
    #   |> Ecto.build_assoc(:last_selected_channel, %{
    #     name: "General",
    #     private: false,
    #     description: "A channel for general discussions.",
    #     server: server
    #   })
    #   |> Repo.insert()

    #   server_user
    #   |> Repo.preload(:server)
    # end)
    {:ok, %{insert_server_user: server_user}} = Ecto.Multi.new()
    |> Ecto.Multi.insert(:insert_server, Server.changeset(%Server{}, attrs))
    |> Ecto.Multi.run(:insert_server_user, fn repo, %{insert_server: server} = test ->
      repo.insert(ServerUser.changeset(%ServerUser{}, %{
        server_id: server.id,
        user_id: user.id
      }))
    end)
    |> Ecto.Multi.run(:insert_default_channel, fn repo, %{insert_server_user: server_user} = test->
      repo.insert(Channel.changeset(%Channel{}, %{
        name: "General",
        private: false,
        description: "A channel for general discussions.",
        server_id: server_user.server_id
      }))
    end)
    |> Ecto.Multi.update(:update_last_selected_server, fn %{insert_server_user: server_user, insert_default_channel: default_channel} = test->
      Ecto.Changeset.change(server_user, %{
        last_selected_channel_id: default_channel.id
      })
    end)
    |> Repo.transaction()

    server_user = server_user
    |> Repo.preload(:user)
    |> Repo.preload(:server)

    {:ok, server_user}
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
end
