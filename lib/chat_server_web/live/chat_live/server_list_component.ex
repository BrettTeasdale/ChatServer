defmodule ChatServerWeb.ChatLive.ServerListComponent do
  use ChatServerWeb, :live_component

  alias ChatServer.Servers;

  def render(assigns) do
    ~H"""
      <div>
        SERVER LIST
      </div>
    """
  end

  def mount(socket) do
    socket = socket
    |> stream(:servers, Servers.list_servers())

    #%{current_user: current_user} = socket.assigns
    IO.inspect(socket)

    {:ok, socket}
  end

  def update(assigns, socket) do

    if connected?(socket) do
      Servers.server_list_subscribe(assigns.current_user.id)
    end

    {:ok, socket}
  end

  def handle_info({:server_created, server}, socket) do
    socket = socket
    |> stream_insert(:servers, server, at: 0)

    {:noreply, socket}
  end

  def handle_info({:server_removed, server}, socket) do
    socket = socket
    |> stream_delete(:servers, server)

    {:noreply, socket}
  end
end
