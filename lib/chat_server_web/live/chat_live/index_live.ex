defmodule ChatServerWeb.ChatLive.Index do
  use ChatServerWeb, :live_view

  import ChatServerWeb.CustomComponents

  alias ChatServer.Accounts

  alias ChatServer.Servers
  alias ChatServer.Servers.Channel
  alias ChatServer.Servers.Message
  alias ChatServer.Servers.Server
  alias ChatServer.Servers.ServerUser
  alias ChatServer.Servers.Upload

  alias ChatServerWeb.Presence

  alias ChatServerWeb.ChatLive.ChannelCreateModalComponent
  alias ChatServerWeb.ChatLive.FindServerModalComponent
  alias ChatServerWeb.ChatLive.ServerCreateModalComponent

  on_mount {ChatServerWeb.UserAuth, :ensure_authenticated}

  @presence_topic "chat_users"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Servers.server_list_subscribe(socket.assigns.current_user.id)

      {:ok, _} =
        Presence.track(self(), @presence_topic, socket.assigns.current_user.id, %{
          online_at: System.system_time(:second)
        })

      Phoenix.PubSub.subscribe(ChatServer.PubSub, "updates:" <> @presence_topic)
    end

    socket =
      socket
      |> assign(:modal_action, nil)
      |> assign(:check_errors, false)
      |> stream(:presences, [])
      |> assign(:message_form, to_form(Servers.change_message(%Message{})))
      |> assign(:selected_server_user, %ServerUser{})
      |> assign(:selected_channel, %Channel{})
      |> assign(:server_users, Servers.list_user_server_users(socket.assigns.current_user.id))
      |> assign(:channels, [])
      |> assign(:channel_page_data, %{})
      |> assign(:last_viewport_event, System.monotonic_time())
      |> assign(:message_page_size, 50)
      |> assign(:sidebar_action, :users)
      |> assign(:search_form, to_form(%{}))
      |> stream(:search_results, [])
      |> assign(:last_search_viewport_event, System.monotonic_time())
      |> assign(:search_page_size, 50)
      |> assign(:search_query, "")
      |> assign(:default_channel_id, nil)
      |> allow_upload(:message_uploads, accept: :any, max_entries: 10, auto_upload: false)

    {:ok, socket}
  end

  # Handle Server Create Modal Events

  def handle_event("show_server_create_modal", _, socket),
    do: {:noreply, assign(socket, :modal_action, "server_create_modal")}

  def handle_event("show_find_server_modal", _, socket),
    do: {:noreply, assign(socket, :modal_action, "find_server_modal")}

  def handle_event("show_channel_create_modal", _, socket),
    do: {:noreply, assign(socket, :modal_action, "channel_create_modal")}

  def handle_event("hide_modals", _, socket), do: {:noreply, assign(socket, :modal_action, nil)}

  def handle_info("hide_modals", socket), do: {:noreply, assign(socket, :modal_action, nil)}

  def handle_event(
        "send_message",
        %{"message" => message_params, "channel-id" => channel_id},
        socket
      ) do
    %{current_user: user} = socket.assigns

    case Servers.create_message(user.id, channel_id, message_params) do
      {:ok, message} ->
        changeset = Servers.change_message(%Message{})
        |> Map.put(:action, :validate)

        Servers.chat_broadcast(channel_id, {:message_created, message})

        {:noreply,  assign(socket, :message_form, to_form(changeset))}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:message_form, to_form(changeset))
          |> assign(:check_errors, true)

        {:noreply, socket}
    end
  end

  def handle_event(
        "prev-page",
        %{"channel_id" => channel_id, "last_message_id" => last_message_id},
        socket
      ) do
    case socket.assigns.last_viewport_event + 500_000_000 < System.monotonic_time() do
      true ->
        socket =
          socket
          |> previous_page({:previous_page, channel_id, last_message_id})

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def previous_page(socket, {:previous_page, channel_id, last_message_id})
      when is_binary(channel_id) and is_binary(last_message_id) do
    channel_id = String.to_integer(channel_id)
    last_message_id = String.to_integer(last_message_id)

    previous_page(socket, {:previous_page, channel_id, last_message_id})
  end

  def previous_page(socket, {:previous_page, channel_id, last_message_id}) do
    previous_page_messages =
      Servers.list_channel_messages_previous(
        channel_id,
        last_message_id,
        socket.assigns.message_page_size
      )

    if(previous_page_messages != []) do
      Enum.reduce(previous_page_messages, socket, fn message, acc_socket ->
        stream_insert(acc_socket, "messages_#{channel_id}", message,
          at: 0,
          limit: 2 * socket.assigns.message_page_size
        )
      end)
      |> assign(:last_viewport_event, System.monotonic_time())
    else
      socket
    end
  end

  def handle_event(
        "next-page",
        %{"channel_id" => channel_id, "last_message_id" => last_message_id},
        socket
      ) do
    case socket.assigns.last_viewport_event + 500_000_000 < System.monotonic_time() do
      true ->
        {:noreply, next_page(socket, {:next_page, channel_id, last_message_id})}

      _ ->
        {:noreply, socket}
    end
  end

  def next_page(socket, {:next_page, channel_id, last_message_id})
      when is_binary(channel_id) and is_binary(last_message_id) do
    channel_id = String.to_integer(channel_id)
    last_message_id = String.to_integer(last_message_id)

    next_page(socket, {:next_page, channel_id, last_message_id})
  end

  def next_page(socket, {:next_page, channel_id, last_message_id}) do
    next_page_messages =
      Servers.list_channel_messages_next(
        channel_id,
        last_message_id,
        socket.assigns.message_page_size
      )

    if(next_page_messages != []) do
      Enum.reduce(next_page_messages, socket, fn message, acc_socket ->
        stream_insert(acc_socket, "messages_#{channel_id}", message,
          at: -1,
          limit: -2 * socket.assigns.message_page_size
        )
      end)
      |> assign(:last_viewport_event, System.monotonic_time())
    else
      socket
    end
  end

  # Search history

  def handle_event("search-prev-page", %{"last_message_id" => last_message_id}, socket) do
    case socket.assigns.last_search_viewport_event + 500_000_000 < System.monotonic_time() do
      true ->
        {:noreply, previous_search_page(socket, last_message_id)}

      _ ->
        {:noreply, socket}
    end
  end

  def previous_search_page(socket, last_message_id) when is_binary(last_message_id) do
    previous_search_page(socket, String.to_integer(last_message_id))
  end

  def previous_search_page(socket, last_message_id) do
    previous_search_page_messages =
      Servers.search_messages_previous(
        socket.assigns.search_query,
        last_message_id,
        socket.assigns.search_page_size
      )

    if(previous_search_page_messages != []) do
      Enum.reduce(previous_search_page_messages, socket, fn message, acc_socket ->
        stream_insert(acc_socket, :search_results, message,
          at: -1,
          limit: -2 * socket.assigns.search_page_size
        )
      end)
      |> assign(:last_search_viewport_event, System.monotonic_time())
    else
      socket
    end
  end

  def handle_event("search-next-page", %{"last_message_id" => last_message_id}, socket) do
    case socket.assigns.last_search_viewport_event + 500_000_000 < System.monotonic_time() do
      true ->
        {:noreply, next_search_page(socket, last_message_id)}

      _ ->
        {:noreply, socket}
    end
  end

  def next_search_page(socket, last_message_id) when is_binary(last_message_id) do
    next_search_page(socket, String.to_integer(last_message_id))
  end

  def next_search_page(socket, last_message_id) do
    next_search_page_messages =
      Servers.search_messages_next(
        socket.assigns.search_query,
        last_message_id,
        socket.assigns.search_page_size
      )

    if(next_search_page_messages != []) do
      Enum.reduce(next_search_page_messages, socket, fn message, acc_socket ->
        stream_insert(acc_socket, :search_results, message,
          at: 0,
          limit: 2 * socket.assigns.search_page_size
        )
      end)
      |> assign(:last_search_viewport_event, System.monotonic_time())
    else
      socket
    end
  end

  # Handle broadcasts of PubSub events for the server list

  def handle_info(:servers_updated, socket) do
    {:noreply,
     assign(socket, :server_users, Servers.list_user_server_users(socket.assigns.current_user.id))}
  end

  def handle_info({:channel_created, %Channel{} = channel}, socket) do
    Servers.chat_subscribe(channel.id)

    socket =
      socket
      |> assign(
        :channels,
        Servers.list_server_user_channels(socket.assigns.selected_server_user.server_id)
      )
      |> assign(:selected_channel, channel)
      |> stream("messages_#{channel.id}", [])

    {:noreply, socket}
  end

  def handle_info({:message_created, %Message{} = message}, socket) do
    # Update the last message that will be the relative anchor of our pagination
    bottom_message =
      Map.get(
        Map.get(socket.assigns.channel_page_data, message.channel_id, %Message{}),
        :bottom_message,
        %Message{}
      )

    ## current_page = Map.get(socket.assigns.channel_page, message.channel_id, 0)

    socket =
      if !Map.get(bottom_message, :id) ||
           Map.get(bottom_message, :id, 0) ==
             Map.get(
               Map.get(
                 Map.get(socket.assigns.channel_page_data, message.channel_id),
                 :bottom_message
               ),
               :id
             ) do
        new_channel_page_data_entry =
          Map.get(socket.assigns.channel_page_data, message.channel.id, %{})
          |> Map.put(:bottom_message, message)

        new_channel_page_data_entry =
          if Map.get(new_channel_page_data_entry, :top_message) do
            new_channel_page_data_entry
          else
            Map.put(new_channel_page_data_entry, :top_message, message)
          end

        socket
        |> stream_insert("messages_#{message.channel.id}", message,
          at: -1,
          limit: -2 * socket.assigns.message_page_size
        )
        |> assign(
          :channel_page_data,
          Map.put(
            socket.assigns.channel_page_data,
            message.channel.id,
            new_channel_page_data_entry
          )
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:server_removed, %ServerUser{} = server_user}, socket) do
    {:noreply, stream_delete(socket, :servers, server_user)}
  end

  # Handle select server event
  def handle_event("select_server_user", %{"server-user-id" => server_user_id}, socket) do
    {:noreply, select_server_user(socket, String.to_integer(server_user_id))}
  end

  def select_server_user(socket, server_user_id, params \\ []) do
    # override default channel
    channel_id = Keyword.get(params, :channel_id, nil)
    # messages for the current channel
    messages = Keyword.get(params, :messages, nil)

    # Get what will be the previous selected server user
    %{selected_server_user: previous_selected_server_user} = socket.assigns

    # Unsubcribe from the previous selected server user's channels
    if Map.get(previous_selected_server_user, :id) && connected?(socket) do
      Servers.channel_list_unsubscribe(
        socket.assigns.current_user.id,
        socket.assigns.selected_server_user.server_id
      )

      previous_channels =
        Servers.list_server_user_channels(previous_selected_server_user.server_id)

      for previous_channel <- previous_channels, do: Servers.chat_unsubscribe(previous_channel.id)
    end

    selected_server_user = Servers.get_server_user!(server_user_id)
    server_users = Servers.list_user_server_users(socket.assigns.current_user.id)

    selected_channel =
      Servers.get_channel!(
        if channel_id != nil, do: channel_id, else: selected_server_user.last_selected_channel_id
      )

    channels = Servers.list_server_user_channels(selected_server_user.server_id)

    users_belonging_to_server =
      Servers.list_users_belonging_to_server(selected_server_user.server_id)

    presences = get_channel_users_presences(users_belonging_to_server)

    socket = stream(socket, :presences, presences, reset: true)

    latest_channel_messages =
      get_latest_channel_messages(channels, socket.assigns.message_page_size)

    channel_page_data = get_channel_page_data(channels, latest_channel_messages)

    default_channel = Enum.find(channels, fn channel -> channel.is_default end)

    socket =
      socket
      |> assign(:modal_action, nil)
      |> assign(:selected_server_user, selected_server_user)
      |> assign(:selected_channel, selected_channel)
      |> assign(:server_users, server_users)
      |> assign(:channels, channels)
      |> assign(:channel_page_data, channel_page_data)
      |> assign(:default_channel_id, Map.get(default_channel, :id, nil))

    socket =
      Enum.reduce(channels, socket, fn channel, acc_socket ->
        stream(
          acc_socket,
          "messages_#{channel.id}",
          if(selected_channel.id == channel.id && messages != nil,
            do: messages,
            else: Map.get(latest_channel_messages, channel.id)
          ), reset: true)
      end)

    if connected?(socket) do
      Servers.channel_list_subscribe(
        socket.assigns.current_user.id,
        socket.assigns.selected_server_user.server_id
      )

      for channel <- channels, do: Servers.chat_subscribe(channel.id)
    end

    socket
  end

  defp get_latest_channel_messages(channels, page_size) do
    for channel <- channels, into: %{} do
      {channel.id, Servers.list_latest_channel_messages(channel.id, page_size)}
    end
  end

  defp get_channel_users_presences(users) do
    for user <- users do
      case Presence.get_by_key(@presence_topic, user.id) do
        nil ->
          %{id: user.username, online: false}

        presence ->
          %{id: user.username, online: true}
      end
    end
  end

  defp get_channel_page_data(channels, latest_channel_messages) do
    for channel <- channels, into: %{} do
      bottom_message = Map.get(latest_channel_messages, channel.id) |> List.last(%Message{})

      {channel.id,
       %{
         top_message: Servers.get_channel_first_message(channel.id) || %Message{},
         bottom_message: bottom_message
       }}
    end
  end

  # Handle select server event
  def handle_event("select_channel", %{"channel-id" => channel_id}, socket) do
    channel = Servers.get_channel!(channel_id)

    socket =
      socket
      |> assign(:selected_channel, channel)
      |> assign(
        :channels,
        Servers.list_server_user_channels(socket.assigns.selected_server_user.server_id)
      )

    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:sidebar_action, :search)
      |> assign(:search_query, query)
      |> stream(:search_results, Servers.search_messages(query, 40), reset: true)

    {:noreply, socket}
  end

  def update(%{message_uploads: message_uploads} = assigns, socket) do
    changeset = Uploads.change_upload(message_uploads)

    socket =
      socket
      |> allow_upload(:message_uploads, accept: :any, max_entries: 10, auto_upload: false)
      |> assign(assigns)
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  def handle_event("validate_message", _assigns, socket) do
    {:noreply, socket}
  end

  def handle_event("select_search_message", %{"message_id" => message_id}, socket) do
    message = Servers.get_message!(message_id, [:channel, :user])

    server_user =
      Servers.get_server_user_by_server_and_user!(
        message.channel.server_id,
        socket.assigns.current_user.id
      )

    socket =
      socket
      |> select_server_user(server_user.id,
        channel_id: message.channel.id,
        messages:
          Servers.list_channel_messages_from_message_id(
            message_id,
            socket.assigns.message_page_size
          )
      )

    {:noreply, socket}
  end

  def handle_info({:user_joined, presence}, socket) do
    if Map.get(socket.assigns.selected_server_user, :id, false) do
      user = Accounts.get_user!(presence.id)

      new_presence = %{
        id: user.username,
        online: true
      }

      {:noreply, stream_insert(socket, :presences, new_presence)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:user_left, presence}, socket) do
    if Map.get(socket.assigns.selected_server_user, :id, false) do
      user = Accounts.get_user!(presence.id)

      new_presence = %{
        id: user.username
      }

      if presence.metas == [] do
        {:noreply, stream_insert(socket, :presences, Map.put(new_presence, :online, false))}
      else
        {:noreply, stream_insert(socket, :presences, Map.put(new_presence, :online, true))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_channel", %{"channel_id" => channel_id}, socket) do
    Servers.delete_channel(channel_id)

    Servers.channel_list_broadcast(
      socket.assigns.current_user.id,
      socket.assigns.selected_server_user.server_id,
      {:channel_deleted, channel_id}
    )

    {:noreply, socket}
  end

  def handle_info({:channel_deleted, channel_id}, socket) do
    Servers.chat_unsubscribe(channel_id)

    socket =
      socket
      |> assign(
        :channels,
        Servers.list_server_user_channels(socket.assigns.selected_server_user.server_id)
      )
      |> assign(:channel_page_data, Map.delete(socket.assigns.channel_page_data, channel_id))
      |> stream("messages_#{channel_id}", [], reset: true)

    {:noreply, socket}
  end

  def handle_event("delete_server", %{"server_id" => server_id}, socket) do
    server_id = String.to_integer(server_id)
    users = Servers.list_users_belonging_to_server(server_id)

    Servers.delete_server(server_id)

    socket =
      if socket.assigns.selected_server_user.server_id == server_id do
        socket =
          Enum.reduce(socket.assigns.channels, socket, fn channel, acc_socket ->
            Servers.chat_unsubscribe(channel.id)
            stream(acc_socket, "messages_#{channel.id}", [], reset: true)
          end)

        socket
        |> assign(:selected_server_user, %ServerUser{})
        |> assign(:selected_channel, %Channel{})
        |> assign(:channels, [])
        |> assign(:channel_page_data, %{})
        |> stream(:presences, [], reset: true)
      else
        socket
      end

    for user <- users do
      Servers.server_list_broadcast(user.id, :servers_updated)
    end

    {:noreply, socket}
  end
end
