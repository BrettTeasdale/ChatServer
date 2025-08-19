defmodule ChatServerWeb.ChatLive.Index do
  use ChatServerWeb, :live_view

  alias ChatServer.Repo
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

    socket =
      socket
      |> assign(check_errors: false)
      |> assign(:message_form, to_form(Servers.change_message(%Message{})))
      |> assign(:selected_server_user, nil)
      |> assign(:selected_channel, nil)
      |> assign(:server_users, Servers.list_user_servers(socket.assigns.current_user))
      |> assign(:channels, [])
      |> assign(:action, nil)

    {:ok, socket}
  end

  def handle_params(params, _, socket) do
    {:noreply, assign(socket, :action, params["action"])}
  end

  def handle_event(
        "send_message",
        %{"message" => message_params, "channel-id" => channel_id},
        socket
      ) do
    %{current_user: user} = socket.assigns

    # message_params = Map.put(message_params, "channel_id", channel_id)
    # |> Map.put(message_params, "user_id", user.id)

    case Servers.create_message(user, Servers.get_channel!(channel_id), message_params) do
      {:ok, message} ->
        changeset = Servers.change_message(%Message{})

        socket =
          socket
          |> assign(:message_form, to_form(changeset))

        Servers.chat_broadcast(channel_id, {:message_created, message})

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:message_form, to_form(changeset))
          |> assign(:check_errors, true)

        {:noreply, socket}
    end
  end

  # Handle select server event
  def handle_event("select_server_user", %{"server-user-id" => server_user_id}, socket) do
    {:noreply, assign_server(socket, server_user_id)}
  end

  # Handle select server event
  def handle_event("select_channel", %{"channel-id" => channel_id}, socket) do
    channel = Servers.get_channel!(channel_id)

    socket =
      socket
      |> assign(:selected_channel, channel)

    {:noreply, socket}
  end

  # Handle broadcasts of PubSub events for the server list

  def handle_info({:server_created, server_user}, socket) do
    {:noreply, assign_server(socket, server_user)}
  end

  def handle_info({:channel_created, channel}, socket) do
    socket =
      socket
      |> assign(:channels, Servers.list_server_user_channels(socket.assigns.selected_server_user))
      |> assign(:selected_channel, channel)
      |> stream("messages_#{channel.id}", Servers.list_latest_channel_messages(channel),
        reset: true,
        limit: -10
      )

    Servers.chat_subscribe(channel.id)

    {:noreply, socket}
  end

  def handle_info({:message_created, %Message{} = message}, socket) do
    {:noreply,
     stream_insert(socket, "messages_#{message.channel.id}", message, at: -1, limit: -10)}
  end

  def handle_info({:server_removed, _server_user}, socket) do
    # {:noreply, stream_delete(socket, :servers, server_user)}
    {:noreply, socket}
  end

  defp assign_server(socket, nil), do: socket

  defp assign_server(socket, server_user_id) when is_binary(server_user_id) do
    server_user = Servers.get_server_user!(server_user_id)
    assign_server(socket, server_user)
  end

  defp assign_server(socket, %ServerUser{} = server_user) do
    server_user = Repo.preload(server_user, [:last_selected_channel])

    if socket.assigns.selected_server_user do
      Servers.channel_list_unsubscribe(
        socket.assigns.current_user.id,
        socket.assigns.selected_server_user.server_id
      )

      socket.assigns.selected_server_user
      |> Servers.list_server_user_channels()
      |> Enum.each(&Servers.chat_unsubscribe(&1.id))
    end

    channels = Servers.list_server_user_channels(server_user)

    socket =
      socket
      |> assign(:selected_server_user, server_user)
      |> assign(:selected_channel, server_user.last_selected_channel || List.first(channels))
      |> assign(:channels, channels)

    socket =
      Enum.reduce(channels, socket, fn channel, acc_socket ->
        stream(
          acc_socket,
          "messages_#{channel.id}",
          Servers.list_latest_channel_messages(channel),
          reset: true,
          limit: -10
        )
      end)

    Servers.channel_list_subscribe(
      socket.assigns.current_user.id,
      socket.assigns.selected_server_user.server_id
    )

    Enum.each(channels, &Servers.chat_subscribe(&1.id))

    socket
  end
end
