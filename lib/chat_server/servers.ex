defmodule ChatServer.Servers do
  @moduledoc """
  The Servers context.
  """

  import Ecto.Query, warn: false
  alias ChatServer.Repo

  alias ChatServer.Servers.Server
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
    %Server{user: user}
    |> Server.changeset(attrs)
    |> Repo.insert()
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
