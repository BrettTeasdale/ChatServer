defmodule ChatServerWeb.ChatLive.Index do
  use ChatServerWeb, :live_view

  import ChatServerWeb.CustomComponents

  alias ChatServer.Servers.Server
  alias ChatServer.Servers.ServerUser
  alias ChatServer.Servers.Channel
  alias ChatServer.Servers.Message
  alias ChatServer.Servers

  alias ChatServerWeb.ChatLive.ServerCreateModalComponent
  alias ChatServerWeb.ChatLive.ChannelCreateModalComponent

  on_mount {ChatServerWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do

    if connected?(socket) do
      Servers.server_list_subscribe(socket.assigns.current_user.id)
    end

    channels = []

    socket = socket
    |> assign(:modal_action, nil)
    |> assign(check_errors: false)
    |> assign(:message_form, to_form(Servers.change_message(%Message{})))
    |> assign(:selected_server_user, %ServerUser{})
    |> assign(:selected_channel, %Channel{})
    |> assign(:server_users, Servers.list_user_servers(socket.assigns.current_user.id))
    |> assign(:channels, channels)
    |> assign(:channel_last_message, %{})
    |> assign(:channel_page, %{})

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col w-screen h-screen p-0 m-0">
      <div class="w-full text-center" :if={Map.get(@selected_server_user, :id)}>
        {@selected_server_user.server.name}
      </div>
      <div class="w-full text-center" :if={!Map.get(@selected_server_user, :id)}>
        Select a Server
      </div>
      <div class="flex flex-row h-full p-0 m-0">
        <div class="h-full w-40 overflow-y-scroll">
          <div>
            <.button phx-click="show_server_create_modal">Create Server</.button>
          </div>
          <div id="server_list">
            <div :for={server_user <- @server_users}>
              <button phx-click="select_server_user" phx-value-server-user-id={server_user.id} class={@selected_server_user && server_user.id == @selected_server_user.id && "selected"}>
                {server_user.server.name}
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-col w-80 h-full m-0 overflow-y-scroll">
          <div :if={Map.get(@selected_server_user, :id)}>
            <.button phx-click="show_channel_create_modal">Create Channel</.button>
          </div>
          <div class="flex-1">
            <div :for={channel <- @channels}>
              <button phx-click="select_channel" phx-value-channel-id={channel.id} class={@selected_channel && channel.id == @selected_channel.id && "selected"}>
                # {channel.name}
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-col w-full h-full">
          <div class="flex flex-row">
            <div class="flex-1">
              <h3># {@selected_channel.name}</h3>
            </div>
            <div class="mr-8">
              <input type="text" name="query" value="" placeholder="Search..." />
            </div>
          </div>
          <%= for channel <- @channels do %>
            <div class={["flex flex-col h-full channel_view", (channel.id != Map.get(@selected_channel, :id) && "hidden")]}>
              <div class="flex flex-1 flex-col w-full" phx-update="stream" id={"messages_#{channel.id}"}>
                <div :for={{dom_id, message} <- @streams["messages_#{channel.id}"]} id={dom_id} data-user={message.user_id} class="message">
                  <div class="font-semibold user">
                    {message.user.username}
                  </div>
                  <div class="w-full">
                    {message.message}
                  </div>
                </div>
              </div>
              <div class="w-full">
                <form
                  class="flex flex-row w-full m-0 p-0"
                  id="server_create_form"
                  phx-submit="send_message"
                  phx-value-channel-id={@selected_channel.id}
                >
                  <div class="flex-1 m-0">
                    <!--<.input class="w-full p-0 m-0" field={@server_create_form[:name]} type="text" placeholder="Message" />-->
                    <input type="text" name="message[message]" id="message" class="m-0 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border-zinc-300 focus:border-zinc-400" placeholder="Message">
                  </div>
                  <div class="w-32 m-0">
                    <.button class="w-32 m-0">Send Message</.button>
                  </div>
                </form>
              </div>
            </div>
          <% end %>
          </div>
        </div>
      </div>
    """
  end

  # Handle Server Create Modal Events

  def handle_event("show_server_create_modal", _, socket) do
    #send_update(ServerCreateModalComponent, id: "chat_server_create_form", action: :show_server_create_modal)
    socket = assign(socket, :modal_action, "server_create_modal")
    {:noreply, socket}
  end

  def handle_event("show_channel_create_modal", _, socket) do
    socket = assign(socket, :modal_action, "channel_create_modal")
    {:noreply, socket}
  end

  def handle_event("hide_modals", _, socket) do
    #send_update(ServerCreateModalComponent, id: "chat_server_create_form", action: :show_server_create_modal)
    socket = assign(socket, :modal_action, nil)
    {:noreply, socket}
  end

  def handle_info("hide_modals", socket) do
    #send_update(ServerCreateModalComponent, id: "chat_server_create_form", action: :show_server_create_modal)
    socket = assign(socket, :modal_action, nil)
    {:noreply, socket}
  end

  def handle_event("send_message", %{"message" => message_params, "channel-id" => channel_id}, socket) do
    %{current_user: user } = socket.assigns

    #message_params = Map.put(message_params, "channel_id", channel_id)
    #|> Map.put(message_params, "user_id", user.id)

    case Servers.create_message(user, Servers.get_channel!(channel_id), message_params) do
    {:ok, message} ->
      changeset = Servers.change_message(%Message{})

      socket = socket
      |> assign(:message_form, to_form(changeset))

      Servers.chat_broadcast(channel_id, {:message_created, message})

      {:noreply, socket}

     {:error, changeset} ->
      socket = socket
      |> assign(:message_form, to_form(changeset))
      |> assign(:check_errors, true)

      {:noreply, socket}
    end
  end

  # Handle broadcasts of PubSub events for the server list

  def handle_info({:server_created, %ServerUser{} = _server_user}, socket) do
    {:noreply, assign(socket, :server_users, Servers.list_user_servers(socket.assigns.current_user.id))}
  end

  def handle_info({:channel_created, %Channel{} = channel}, socket) do
    {:noreply, assign(socket, :channels, Servers.list_server_user_channels(socket.assigns.selected_server_user.id))}
  end

  def handle_info({:message_created, %Message{} = message}, socket) do

    # Update the last message that will be the relative anchor of our pagination
    current_last_message = Map.get(socket.assigns.channel_last_message, message.channel_id, %Message{})
    current_page = Map.get(socket.assigns.channel_page, message.channel_id, 0)

    socket = if !Map.get(current_last_message, :id) || (Map.get(current_last_message, :id) && current_page == 0) do
      IO.inspect("YES")
      socket = socket
      |> stream_insert("messages_#{message.channel.id}", message, at: -1, limit: -10)
      |> assign(:channel_last_message, Map.put(socket.assigns.channel_last_message, message.channel.id, message))

      socket
    else
      IO.inspect("no")
      socket
    end

    {:noreply, socket}
  end

  def handle_info({:server_removed, %ServerUser{} = server_user}, socket) do
    {:noreply, stream_delete(socket, :servers, server_user)}
  end

  # Handle select server event
  def handle_event("select_server_user", %{"server-user-id" => server_user_id}, socket) do
    # Get what will be the previous selected server user
    %{selected_server_user: previous_selected_server_user } = socket.assigns

    # Unsubcribe from the previous selected server user's channels
    if Map.get(previous_selected_server_user, :id) && connected?(socket) do
      Servers.channel_list_unsubscribe(socket.assigns.current_user.id, socket.assigns.selected_server_user.server_id)

      previous_channels = Servers.list_server_user_channels(previous_selected_server_user.user_id)
      for previous_channel <- previous_channels, do: Servers.chat_unsubscribe(previous_channel.id)
    end

    selected_server_user = Servers.get_server_user!(server_user_id)
    server_users = Servers.list_user_servers(socket.assigns.current_user.id)
    selected_channel = Servers.get_channel!(selected_server_user.last_selected_channel_id)
    channels = Servers.list_server_user_channels(selected_server_user.server_id)

    socket = socket
    |> assign(:modal_action, nil)
    |> assign(:selected_server_user, selected_server_user)
    |> assign(:selected_channel, selected_channel)
    |> assign(:server_users, server_users)
    |> assign(:channels, channels)

    socket = Enum.reduce(channels, socket, fn channel, acc_socket ->
      stream(acc_socket, "messages_#{channel.id}", Servers.list_latest_channel_messages(channel), reset: true, limit: -10)
    end)

    if connected?(socket) do
      Servers.channel_list_subscribe(socket.assigns.current_user.id, socket.assigns.selected_server_user.server_id)

      for channel <- channels, do: Servers.chat_subscribe(channel.id)
    end

    {:noreply, socket}
  end

  # Handle select server event
  def handle_event("select_channel", %{"channel-id" => channel_id}, socket) do
    channel = Servers.get_channel!(channel_id)

    socket = socket
    |> assign(:selected_channel, channel)
    |> assign(:channels, Servers.list_server_user_channels(socket.assigns.selected_server_user.id))

    {:noreply, socket}
  end
end
