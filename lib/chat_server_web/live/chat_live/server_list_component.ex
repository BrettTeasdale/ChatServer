defmodule ChatServerWeb.ChatLive.ServerListComponent do
  use ChatServerWeb, :live_component

  alias ChatServer.Servers;
  alias ChatServer.Servers.ServerUser;

  def render(assigns) do
    ~H"""
      <div phx-update="stream" id="server_list">
        <div :for={{dom_id, server_user} <- @streams.server_users} id={dom_id}>
          {server_user.server.name}
        </div>
      </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end

  def update(%{action: :server_created, server_user: %ServerUser{} = server_user}, socket) do
    socket = socket
    |> stream_insert(:server_users, server_user, at: 0)

    {:ok, socket}
  end

  def update(%{action: :server_removed, server_user: %ServerUser{} = server_user}, socket) do
    socket = socket
    |> stream_delete(:servers, server_user)

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket = socket
    |> assign(:current_user, assigns.current_user)
    |> stream(:server_users, Servers.list_user_servers(assigns.current_user))

    {:ok, socket}
  end

end
