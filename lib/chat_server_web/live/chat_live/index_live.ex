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

    channels = Servers.list_server_user_channels(%ServerUser{})

    socket = socket
    |> assign(check_errors: false)
    |> assign(:message_form, to_form(Servers.change_message(%Message{})))
    |> assign(:selected_server_user, %ServerUser{})
    |> assign(:selected_channel, %Channel{})
    |> assign(:server_users, Servers.list_user_servers(socket.assigns.current_user))
    |> assign(:channels, channels)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col w-screen h-screen p-0 m-0">
      <div class="w-full text-center" :if={@selected_server_user.id}>
        {@selected_server_user.server.name}
      </div>
      <div class="w-full text-center" :if={!@selected_server_user.id}>
        Select a Server
      </div>
      <div class="flex flex-row h-full p-0 m-0">
        <div class="h-full w-40 overflow-y-scroll">
          <div>
            <.button phx-click="show_server_create_modal">Create Server</.button>
          </div>
          <div phx-update="stream" id="server_list">
            <div :for={server_user <- @server_users}>
              <button phx-click="select_server_user" phx-value-server-user-id={server_user.id} class={server_user.id == @selected_server_user.id && "selected"}>
                {server_user.server.name}
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-col w-80 h-full m-0 overflow-y-scroll">
          <div :if={Map.get(@selected_server_user, :id)}>
            <.button phx-click="show_channel_create_modal">Create Channel</.button>
          </div>
          <div class="flex-1" id="channel_list" phx-update="stream">
            <div :for={channel <- @channels}>
              <button phx-click="select_channel" phx-value-channel-id={channel.id} class={channel.id == @selected_channel.id && "selected"}>
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
            <div class={["flex flex-col h-full channel_view", (if channel.id != Map.get(@selected_channel, :id), do: "hidden", else: "")]}>
              <div class="flex flex-1 flex-col w-full" phx-update="stream" id={"messages_#{channel.id}"}>
                <% IO.inspect(@streams["messages_#{channel.id}"], label: "streams3") %>
                <div :for={{dom_id, message} <- @streams["messages_#{channel.id}"]} id={dom_id}>
                  <div class="font-semibold">
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
    <div>

    <.modal :if={@action == "create_server"} id="create_server" show>
      <%
      # Putting the show/hide logic in the component itself complicates things
      # since you need to pass a lot of messages back and forward.
      # 
      # I would set an assign that conditionally shows the modal like above
      # 
      # <.link patch={~p"/chat?action=create_server"}>Create Server</.link>
      # 
      # and then you can handle it in your handle_params
      # 
      # def handle_params(params, _, socket) do
      #   {:noreply, assign(socket, :action, params["action"])}
      # end
      %>
      <.live_component module={ServerCreateModalComponent} id="chat_server_create_form" modal_id="server-create-modal" current_user={@current_user} />
    </.modal>

    <.modal :if={@action == "create_modal"} id="create_modal" show>
      <.live_component module={ChannelCreateModalComponent} id="chat_channel_create_form" modal_id="channel-create-modal" current_user={@current_user} />
    </.modal>

    </div>
    """
  end

  # Handle Server Create Modal Events

  def handle_event("show_server_create_modal", _, socket) do
    send_update(ServerCreateModalComponent, id: "chat_server_create_form", action: :show_server_create_modal)
    {:noreply, socket}
  end

  def handle_event("show_channel_create_modal", _, socket) do
    send_update(ChannelCreateModalComponent, id: "chat_channel_create_form", action: :show_channel_create_modal, selected_server_user: socket.assigns.selected_server_user)
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

  def handle_info({:server_created, %ServerUser{} = server_user}, socket) do
    {:noreply, stream_insert(socket, :server_users, server_user, at: -1)}
  end

  def handle_info({:channel_created, %Channel{} = channel}, socket) do
    {:noreply, stream_insert(socket, :channels, channel, at: -1)}
  end

  def handle_info({:message_created, %Message{} = message}, socket) do
    {:noreply, stream_insert(socket, "messages_#{message.channel.id}", message, at: -1, limit: -10)}
  end

  def handle_info({:server_removed, %ServerUser{} = server_user}, socket) do
    {:noreply, stream_delete(socket, :servers, server_user)}
  end

  # Handle select server event
  def handle_event("select_server_user", %{"server-user-id" => server_user_id}, socket) do
    # Get what will be the previous selected server user
    %{selected_server_user: previous_selected_server_user } = socket.assigns

    # Unsubcribe from the previous selected server user's channels
    if Map.get(previous_selected_server_user, :id) do
      Servers.channel_list_unsubscribe(socket.assigns.current_user.id, socket.assigns.selected_server_user.server_id)

      previous_channels = Servers.list_server_user_channels(previous_selected_server_user)
      for previous_channel <- previous_channels, do: Servers.chat_unsubscribe(previous_channel.id)
    end

    server_user = Servers.get_server_user!(server_user_id)
    channels = Servers.list_server_user_channels(server_user)
    IO.inspect(server_user.server.name)

    socket = socket
    |> assign(:selected_server_user, server_user)
    |> assign(:selected_channel, server_user.last_selected_channel)
    |> stream_insert(:server_users, server_user)
    |> stream(:channels, channels, reset: true)
    |> assign(:channels, channels)

    socket = Enum.reduce(channels, socket, fn channel, acc_socket ->
      stream(acc_socket, "messages_#{channel.id}", Servers.list_latest_channel_messages(channel), reset: true, limit: -10)
    end)

    socket = if Map.get(previous_selected_server_user, :id) do
      stream_insert(socket, :server_users, previous_selected_server_user)
    else
      socket
    end

    Servers.channel_list_subscribe(socket.assigns.current_user.id, socket.assigns.selected_server_user.server_id)

    for channel <- channels, do: Servers.chat_subscribe(channel.id)

    IO.inspect(server_user)

    {:noreply, socket}
  end

  # Handle select server event
  def handle_event("select_channel", %{"channel-id" => channel_id}, socket) do
    # Select the current selected channel to update in the channels stream
    previous_selected_channel = socket.assigns.selected_channel

    channel = Servers.get_channel!(channel_id)

    IO.inspect(channel)

    socket = socket
    |> assign(:selected_channel, channel)
    |> stream_insert(:channels, previous_selected_channel)
    |> stream_insert(:channels, channel)

    {:noreply, socket}
  end
end
