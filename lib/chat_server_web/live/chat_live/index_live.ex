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
    |> assign(:channel_page_data, %{})
    |> assign(:last_viewport_event, NaiveDateTime.utc_now)
    |> assign(:prev_page_in_flight, false)
    |> assign(:next_page_in_flight, false)
    |> assign(:message_page_size, 100)

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
            <div class={["flex flex-col h-full channel_view overflow-hidden", (channel.id != Map.get(@selected_channel, :id) && "hidden")]}>
              <div
              class="flex flex-1 flex-col w-full overflow-y-auto"
              phx-update="stream"
              id={"messages_#{channel.id}"}
              phx-viewport-top={JS.push("prev-page", page_loading: true, value: %{channel_id: channel.id})}
              phx-viewport-bottom={JS.push("next-page", page_loading: true, value: %{channel_id: channel.id})}>
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
      <div>
        <.raw_modal :if={@modal_action == "server_create_modal"} id="server-create-modal" hide_event="hide_modals">
          <:header>Create New Server</:header>
          <.live_component module={ServerCreateModalComponent} id="chat_server_create_form" modal_id="server-create-modal" current_user={@current_user} />
        </.raw_modal>

        <.raw_modal :if={@modal_action == "channel_create_modal"} id="channel-create-modal" hide_event="hide_modals">
          <:header>Create New Channel</:header>
          <.live_component module={ChannelCreateModalComponent} id="chat_channel_create_form" modal_id="channel-create-modal" current_user={@current_user} selected_server_user={@selected_server_user} />
        </.raw_modal>
      </div>
    """
  end

  # Handle Server Create Modal Events

  def handle_event("show_server_create_modal", _, socket), do: {:noreply, assign(socket, :modal_action, "server_create_modal")}

  def handle_event("show_channel_create_modal", _, socket), do: {:noreply, assign(socket, :modal_action, "channel_create_modal")}

  def handle_event("hide_modals", _, socket), do: {:noreply, assign(socket, :modal_action, nil)}

  def handle_info("hide_modals", socket), do: {:noreply, assign(socket, :modal_action, nil)}

  def handle_event("send_message", %{"message" => message_params, "channel-id" => channel_id}, socket) do
    %{current_user: user } = socket.assigns

    #message_params = Map.put(message_params, "channel_id", channel_id)
    #|> Map.put(message_params, "user_id", user.id)

    case Servers.create_message(user.id, channel_id, message_params) do
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

  def handle_event("prev-page", %{"channel_id" => channel_id}, socket) do
    case NaiveDateTime.compare(NaiveDateTime.add(NaiveDateTime.utc_now(), -1), socket.assigns.last_viewport_event) do
     :gt ->
        socket = socket
        |> previous_page({:previous_page, channel_id})
        |> assign(:prev_page_in_flight, false)
        {:noreply, socket}
      _ ->
        IO.inspect("THROTTLED")
        socket = if connected?(socket) and !socket.assigns.prev_page_in_flight do
          Process.send_after(self(), {:previous_page, channel_id}, 1000)
          socket |> assign(:prev_page_in_flight, true)
        else
          socket
        end

        {:noreply, socket}
    end
  end

  def handle_info({:previous_page, channel_id}, socket) do
    socket = if(socket.assigns.prev_page_in_flight) do
      previous_page(socket, {:previous_page, channel_id})
    else
      socket
    end

    socket = assign(socket, :prev_page_in_flight, false)

    {:noreply, socket}
  end

  def previous_page(socket, {:previous_page, channel_id}) do
    page_data = Map.get(socket.assigns.channel_page_data, channel_id)

    last_queue_message =  Map.get(page_data, :last_queue_message, %Message{})
    previous_page_messages = Servers.list_previous_channel_messages(channel_id, last_queue_message.id, socket.assigns.message_page_size)

    has_reached_top = Map.get(socket.assigns.channel_page_data, channel_id, %{})[:has_reached_top] || Enum.any?(previous_page_messages, fn msg -> msg.id == page_data.top_message.id end)
    has_reached_bottom = Map.get(socket.assigns.channel_page_data, channel_id, %{})[:has_reached_bottom] || Enum.any?(previous_page_messages, fn msg -> msg.id == Map.get(Map.get(page_data, channel_id), :last_queue_message) end)

    new_page_data = %{
      last_queue_message: Enum.at(previous_page_messages, 0) || last_queue_message,
      top_message: page_data.top_message,
      bottom_message: page_data.bottom_message,
      has_reached_top: has_reached_top,
      has_reached_bottom: has_reached_bottom,
    }

    if(previous_page_messages != []) do
      socket
      |> assign(:channel_page_data, Map.put(socket.assigns.channel_page_data, channel_id, new_page_data))
      |> assign(:last_viewport_event, NaiveDateTime.utc_now())
      |> stream("messages_#{channel_id}", previous_page_messages, reset: true, at: 0)
      #|> stream_insert("messages_#{channel_id}", previous_page_messages, limit: socket.assigns.message_page_size, at: 0)

      # socket = Enum.reduce(previous_page_messages, socket, fn message, acc_socket ->
      #   stream_insert(acc_socket, "messages_#{channel_id}", message, at: -1, limit: socket.assigns.message_page_size * -1)
      # end)
    else
        socket
    end

  end


  def handle_event("next-page", %{"channel_id" => channel_id}, socket) do
    case NaiveDateTime.compare(NaiveDateTime.add(NaiveDateTime.utc_now(), -1), socket.assigns.last_viewport_event) do
     :gt ->
        socket = socket
        |> next_page({:next_page, channel_id})
        |> assign(:next_page_in_flight, false)
        {:noreply, socket}
      _ ->
        IO.inspect("THROTTLED")
        socket = if connected?(socket) and !socket.assigns.next_page_in_flight do
          Process.send_after(self(), {:next_page, channel_id}, 1000)
          socket |> assign(:next_page_in_flight, true)
        else
          socket
        end

        {:noreply, socket}
    end
  end

  def handle_info({:next_page, channel_id}, socket) do
    socket = if(socket.assigns.next_page_in_flight) do
      next_page(socket, {:next_page, channel_id})
    else
      socket
    end

    socket = assign(socket, :next_page_in_flight, false)

    {:noreply, socket}
  end

  def next_page(socket, {:next_page, channel_id}) do
    page_data = Map.get(socket.assigns.channel_page_data, channel_id)

    last_queue_message =  Map.get(page_data, :last_queue_message, %Message{})
    next_page_messages = Servers.list_next_channel_messages(channel_id, last_queue_message.id, socket.assigns.message_page_size)

    has_reached_top = Map.get(socket.assigns.channel_page_data, channel_id, %{})[:has_reached_top] || Enum.any?(next_page_messages, fn msg -> msg.id == page_data.top_message.id end)
    has_reached_bottom = Map.get(socket.assigns.channel_page_data, channel_id, %{})[:has_reached_bottom] || Enum.any?(next_page_messages, fn msg -> msg.id == Map.get(Map.get(page_data, channel_id), :last_queue_message) end)

    new_page_data = %{
      last_queue_message: Enum.at(next_page_messages, 0) || last_queue_message,
      top_message: page_data.top_message,
      bottom_message: page_data.bottom_message,
      has_reached_top: has_reached_top,
      has_reached_bottom: has_reached_bottom,
    }

    if(next_page_messages != []) do
      socket = socket
      |> assign(:channel_page_data, Map.put(socket.assigns.channel_page_data, channel_id, new_page_data))
      |> assign(:last_viewport_event, NaiveDateTime.utc_now())
      |> stream("messages_#{channel_id}", next_page_messages, reset: true, at: 0)
      socket
    else
      socket
    end
  end


  # Handle broadcasts of PubSub events for the server list

  def handle_info({:server_created, %ServerUser{} = _server_user}, socket) do
    {:noreply, assign(socket, :server_users, Servers.list_user_servers(socket.assigns.current_user.id))}
  end

  def handle_info({:channel_created, %Channel{} = channel}, socket) do
    Servers.chat_subscribe(channel.id)

    socket = socket
    |> assign(:channels, Servers.list_server_user_channels(socket.assigns.selected_server_user.server_id))
    |> stream("messages_#{channel.id}", [])

    {:noreply, socket}
  end

  def handle_info({:message_created, %Message{} = message}, socket) do

    # Update the last message that will be the relative anchor of our pagination
    bottom_message = Map.get(Map.get(socket.assigns.channel_page_data, message.channel_id, %Message{}), :bottom_message, %Message{})
    ## current_page = Map.get(socket.assigns.channel_page, message.channel_id, 0)

    socket = if !Map.get(bottom_message, :id) || (Map.get(bottom_message, :id, 0) == Map.get(Map.get(Map.get(socket.assigns.channel_page_data, message.channel_id), :last_queue_message), :id)) do
      IO.inspect("YES")
      socket = socket
      |> stream_insert("messages_#{message.channel.id}", message, at: -1, limit: socket.assigns.message_page_size * -1)
      #|> assign(:channel_last_message, Map.put(socket.assigns.channel_last_message, message.channel.id, message))
      |> assign(:channel_page_data, Map.put(socket.assigns.channel_page_data, message.channel.id, %{socket.assigns.channel_page_data[message.channel.id] |
        last_queue_message: message,
        bottom_message: message,
        has_reached_top: false,
        has_reached_bottom: true,
      }))

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

      previous_channels = Servers.list_server_user_channels(previous_selected_server_user.server_id)
      for previous_channel <- previous_channels, do: Servers.chat_unsubscribe(previous_channel.id)
    end

    selected_server_user = Servers.get_server_user!(server_user_id)
    server_users = Servers.list_user_servers(socket.assigns.current_user.id)
    selected_channel = Servers.get_channel!(selected_server_user.last_selected_channel_id)
    channels = Servers.list_server_user_channels(selected_server_user.server_id)

    latest_channel_messages = for channel <- channels, into: %{} do
      {channel.id, Servers.list_latest_channel_messages(channel.id, socket.assigns.message_page_size)}
    end

    channel_page_data = for channel <- channels, into: %{} do
        bottom_message = Map.get(latest_channel_messages, channel.id) |> List.last(%Message{})

        {channel.id, %{
          top_message: Servers.get_channel_top_message!(channel.id) || %Message{},
          bottom_message: bottom_message,
          last_queue_message: bottom_message,
          has_reached_top: false,
          has_reached_bottom: true,
        }}
    end

    socket = socket
    |> assign(:modal_action, nil)
    |> assign(:selected_server_user, selected_server_user)
    |> assign(:selected_channel, selected_channel)
    |> assign(:server_users, server_users)
    |> assign(:channels, channels)
    |> assign(:channel_page_data, channel_page_data)

    socket = Enum.reduce(channels, socket, fn channel, acc_socket ->
      stream(acc_socket, "messages_#{channel.id}", Map.get(latest_channel_messages, channel.id), reset: true, limit: socket.assigns.message_page_size * -1)
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
    |> assign(:channels, Servers.list_server_user_channels(socket.assigns.selected_server_user.server_id))

    {:noreply, socket}
  end
end
