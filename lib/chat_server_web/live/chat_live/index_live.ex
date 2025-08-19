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

  # This event can get removed if you show the modal via url param
  def handle_event("show_server_create_modal", _, socket) do
    send_update(ServerCreateModalComponent, id: "chat_server_create_form", action: :show_server_create_modal)
    {:noreply, socket}
  end

  # This event can get removed if you show the modal via url param
  def handle_event("show_channel_create_modal", _, socket) do
    send_update(ChannelCreateModalComponent, id: "chat_channel_create_form", action: :show_channel_create_modal, selected_server_user: socket.assigns.selected_server_user)
    {:noreply, socket}
  end

  # And they get replaced with a single handle_params like this
  # def handle_params(params, _, socket) do
  #   {:noreply, assign(socket, :action, params["action"])}
  # end


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
    # If we move these to an assign then you can just re-assign the whole
    # list. It an infrequent action and a quick query so the additional
    # complexity you get by using streams isn't worth the optimization.
    #
    # server_users = Servers.list_user_servers(socket.assigns.current_user)
    # {:noreply, assign(socket, :server_users, server_users)
    #
    # I think you'd need to update this in a couple places
    {:noreply, stream_insert(socket, :server_users, server_user, at: -1)}
  end

  def handle_info({:channel_created, %Channel{} = channel}, socket) do
    # Same here;
    #  channels = Servers.list_server_user_channels(%ServerUser{})
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
