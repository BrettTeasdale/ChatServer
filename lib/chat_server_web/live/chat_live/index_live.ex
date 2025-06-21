defmodule ChatServerWeb.ChatLive.Index do
  use ChatServerWeb, :live_view

  alias ChatServer.Servers.ServerUser;
  alias ChatServer.Servers;

  alias ChatServerWeb.ChatLive.ServerCreateModalComponent
  alias ChatServerWeb.ChatLive.ServerListComponent
  alias ChatServerWeb.ChatLive.ChannelListComponent
  alias ChatServerWeb.ChatLive.ChatViewComponent
  alias ChatServerWeb.ChatLive.UserListComponent

  on_mount {ChatServerWeb.UserAuth, :ensure_authenticated}

  # def update(assigns, socket) do
  #   IO.inspect(assigns)
  #   {:ok, socket}
  # end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Servers.server_list_subscribe(socket.assigns.current_user.id)
    end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      CHAT APP

      <.button phx-click="show_server_create_modal">Create Server</.button>

      <.live_component module={ServerCreateModalComponent} id={:chat_server_create_form} modal_id="server-create-modal" current_user={@current_user} />

      <.live_component module={ServerListComponent} id={:chat_server_list} current_user={@current_user} />

      <.live_component module={ChannelListComponent} id={:chat_channel_list} />

      <.live_component module={ChatViewComponent} id={:chat_view} />

      <.live_component module={UserListComponent} id={:chat_user_list} />

    </div>
    """
  end

  # Handle Server Create Modal Events

  def handle_event("show_server_create_modal", _, socket) do
    send_update(ServerCreateModalComponent, id: :chat_server_create_form, action: :show_server_create_modal)
    {:noreply, socket}
  end

  def handle_info(:hide_server_create_modal, socket) do
    {:noreply, socket}
  end

  # Handle broadcasts of PubSub events for the server list

  def handle_info({:server_created, %ServerUser{} = server_user}, socket) do
    send_update(ServerListComponent, id: :chat_server_list, action: :server_created, server_user: server_user)
    {:noreply, socket}
  end

  def handle_info({:server_removed, %ServerUser{} = server_user}, socket) do
    send_update(ServerListComponent, id: :chat_server_list, action: :server_removed, server_user: server_user)
    {:noreply, socket}
  end
end
