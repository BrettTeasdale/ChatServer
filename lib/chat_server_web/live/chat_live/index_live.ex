defmodule ChatServerWeb.ChatLive.Index do
  use ChatServerWeb, :live_view

  import ChatServerWeb.CustomComponents

  alias ChatServer.Servers.Server
  alias ChatServer.Servers.ServerUser
  alias ChatServer.Servers.Channel
  alias ChatServer.Servers.Message
  alias ChatServer.Servers.Upload
  alias ChatServer.Servers
  alias ChatServer.Accounts

  alias ChatServerWeb.Presence

  alias ChatServerWeb.ChatLive.ServerCreateModalComponent
  alias ChatServerWeb.ChatLive.ChannelCreateModalComponent
  alias ChatServerWeb.ChatLive.FindServerModalComponent

  on_mount {ChatServerWeb.UserAuth, :ensure_authenticated}

  defp presence_topic do
    "chat_users"
  end

  def mount(_params, _session, socket) do

    if connected?(socket) do
      Servers.server_list_subscribe(socket.assigns.current_user.id)

      {:ok, _} = Presence.track(self(), presence_topic(), socket.assigns.current_user.id, %{
        online_at: System.system_time(:second)
      })

      Phoenix.PubSub.subscribe(ChatServer.PubSub, "updates:" <> presence_topic())
    end

    socket = socket
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

  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-gray-900 text-gray-100">
      <!-- Server Sidebar -->
      <div class="w-20 bg-gray-800 flex flex-col items-center py-4 gap-4 border-r border-gray-700">
        <div id="server_list" class="flex flex-col gap-4 w-full overflow-y-scroll">
          <div :for={server_user <- @server_users} class="relative group">
            <div
              phx-click="select_server_user"
              phx-value-server-user-id={server_user.id}
              phx-hook="contextMenu"
              id={"select_server_#{server_user.server.id}"}
              data-context_menu_id={"server_context_#{server_user.server.id}"}
              class={[
                "w-12 h-12 rounded-full bg-indigo-600 flex items-center justify-center cursor-pointer transition-all hover:rounded-lg mx-auto ",
                @selected_server_user && server_user.id == @selected_server_user.id && "rounded-lg bg-indigo-500"
              ]}
              title={server_user.server.name}
            >
              <span class="font-bold text-sm">{String.first(server_user.server.name)}</span>
            </div>
            <div
              id={"server_context_#{server_user.server.id}"}
              class="context_menu hidden absolute left-16 bg-gray-800 rounded shadow-lg z-10 min-w-max"
            >
              <.button
                data-confirm="This action <b>cannot</b> be undone."
                data-confirm-title={"Delete server \"#{server_user.server.name}\"?"}
                data-confirm-button="Delete Server"
                data-confirm-variant="danger"
                data-confirm-icon="hero-exclamation-triangle"
                phx-click="delete_server"
                phx-value-server_id={server_user.server.id}
                class="context_menu_item w-full text-left px-4 py-2 hover:bg-gray-700 text-red-400"
              >
                Delete Server
              </.button>
            </div>
          </div>
        </div>

        <div class="border-t border-gray-700 pt-4 w-full flex flex-col gap-2">
          <button
            phx-click="show_server_create_modal"
            class="w-12 h-12 rounded-full bg-gray-700 hover:bg-green-600 flex items-center justify-center transition-colors mx-auto text-xl"
            title="Create Server"
          >
            +
          </button>
          <button
            phx-click="show_find_server_modal"
            class="w-12 h-12 rounded-full bg-gray-700 hover:bg-blue-600 flex items-center justify-center transition-colors mx-auto text-xl"
            title="Find Server"
          >
            🔍
          </button>
        </div>
      </div>

      <!-- Channels Sidebar -->
      <div class="w-60 bg-gray-800 flex flex-col border-r border-gray-700">
        <!-- Header -->
        <div class="px-4 py-4 border-b border-gray-700">
          <h2 class="font-bold text-lg truncate">
            {if Map.get(@selected_server_user, :id), do: @selected_server_user.server.name, else: "Select a Server"}
          </h2>
        </div>

        <!-- Create Channel Button -->
        <div :if={Map.get(@selected_server_user, :id)} class="px-4 py-2">
          <.button phx-click="show_channel_create_modal" class="w-full bg-indigo-600 hover:bg-indigo-700">
            + Create Channel
          </.button>
        </div>

        <!-- Upload Errors -->
        <div :if={@uploads.message_uploads.errors != []} class="px-4 py-2 bg-red-900/30 border-l-4 border-red-600">
          <%= for {_ref, msg} <- @uploads.message_uploads.errors do %>
            <p class="text-red-400 text-sm"><%= Phoenix.Naming.humanize(msg) %></p>
          <% end %>
        </div>

        <!-- Channels List -->
        <div class="flex-1 overflow-y-auto px-2 py-4 space-y-1">
          <div :for={channel <- @channels} class="relative group">
            <div
              phx-click="select_channel"
              phx-value-channel-id={channel.id}
              phx-hook="contextMenu"
              id={"select_channel_#{channel.id}"}
              data-context_menu_id={if @default_channel_id != channel.id, do: "channel_context_#{channel.id}", else: ""}
              class={[
                "px-3 py-2 rounded cursor-pointer transition-colors",
                @selected_channel && channel.id == @selected_channel.id && "bg-gray-700 text-white",
                !(@selected_channel && channel.id == @selected_channel.id) && "text-gray-400 hover:text-white hover:bg-gray-700/50"
              ]}
            >
              # {channel.name}
            </div>
            <div
              :if={@default_channel_id != channel.id}
              id={"channel_context_#{channel.id}"}
              class="context_menu hidden absolute left-full top-0 ml-2 bg-gray-800 rounded shadow-lg z-10 min-w-max"
            >
              <.button
                data-confirm="This action <b>cannot</b> be undone."
                data-confirm-title={"Delete channel \"#{channel.name}\"?"}
                data-confirm-button="Delete Channel"
                data-confirm-variant="danger"
                data-confirm-icon="hero-exclamation-triangle"
                phx-click="delete_channel"
                phx-value-channel_id={channel.id}
                class="context_menu_item w-full text-left px-4 py-2 hover:bg-gray-700 text-red-400"
              >
                Delete Channel
              </.button>
            </div>
          </div>
        </div>
      </div>

      <!-- Main Content Area -->
      <div class="flex-1 flex flex-col">
        <!-- Top Bar -->
        <div class="bg-gray-800 border-b border-gray-700 px-6 py-4 flex items-center justify-between">
          <h1 class="text-xl font-bold">
            {if Map.get(@selected_channel, :id), do: "# #{@selected_channel.name}", else: "Select a channel"}
          </h1>
          <form phx-submit="search" class="flex">
            <input
              type="text"
              name="query"
              placeholder="Search..."
              class="px-4 py-2 rounded-lg bg-gray-700 text-gray-100 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </form>
        </div>

        <!-- Messages and Sidebar Container -->
        <div class="flex-1 flex overflow-hidden">
          <!-- Messages Area -->
          <div class="flex-1 flex flex-col overflow-hidden">
            <div class={["flex flex-col h-full overflow-hidden"]} :if={!Map.get(@selected_channel, :id, false)}></div>
            <%= for channel <- @channels do %>
              <div class={["flex flex-col h-full overflow-hidden", (channel.id != Map.get(@selected_channel, :id) && "hidden")]}>
                <div
                  class="flex-1 overflow-y-auto px-6 py-4 space-y-4"
                  phx-update="stream"
                  id={"messages_#{channel.id}"}
                  phx-hook="messageScroll"
                  data-channel_id={channel.id}
                >
                  <div
                    :for={{dom_id, message} <- @streams["messages_#{channel.id}"]}
                    id={dom_id}
                    data-user={message.user_id}
                    data-message_id={message.id}
                    class="group hover:bg-gray-700/30 px-4 py-2 rounded transition-colors message"
                  >
                    <div class="flex items-baseline gap-3">
                      <span class="font-semibold text-indigo-400">{message.user.username}</span>
                      <time
                        phx-hook="updateTime"
                        id={"message_#{message.id}"}
                        datetime={DateTime.to_iso8601(message.inserted_at)}
                        class="text-xs text-gray-500 group-hover:text-gray-400"
                      >
                        <%= message.inserted_at %>
                      </time>
                    </div>
                    <p class="text-gray-200 mt-1">{message.message}</p>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Message Input -->
            <div class="bg-gray-800 border-t border-gray-700 px-6 py-4" :if={Map.get(@selected_channel, :id, false)}>
              <.simple_form
                class="flex gap-4"
                for={@message_form}
                id={"server_create_form_#{@selected_channel.id}"}
                phx-submit="send_message"
                phx-change="validate_message"
                phx-value-channel-id={@selected_channel.id}
                no-margin={true}
              >
                <.live_file_input
                  id={"upload_#{@selected_channel.id}"}
                  upload={@uploads.message_uploads}
                  class="hidden"
                />
                <div class="flex-1 flex gap-2">
                  <input
                    type="text"
                    name="message[message]"
                    class="flex-1 px-4 py-2 rounded-lg bg-gray-700 text-gray-100 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    placeholder="Message ##{@selected_channel.name}"
                  />
                  <.button class="bg-indigo-600 hover:bg-indigo-700">Send</.button>
                </div>
              </.simple_form>
            </div>
          </div>



          <!-- Right Sidebar - Search or Users -->
          <div class={["w-64 bg-gray-800 border-l border-gray-700 flex flex-col overflow-hidden", (@sidebar_action == :search || " hidden")]}>
            <div class="px-6 py-4 border-b border-gray-700 font-semibold">Search Results</div>
            <div
              class="flex-1 overflow-y-auto px-4 py-4 space-y-2"
              phx-update="stream"
              id="search_results"
              phx-hook="searchHistoryScroll"
            >
              <div
                :for={{dom_id, message} <- @streams[:search_results]}
                id={dom_id}
                data-channel_id={message.channel_id}
                data-message_id={message.id}
                phx-click="select_search_message"
                phx-value-message_id={message.id}
                class="p-3 rounded cursor-pointer hover:bg-gray-700 transition-colors search_result"
              >
                <div class="text-xs text-gray-400 font-semibold">#{message.channel.name}</div>
                <div class="text-sm mt-1">
                  <span class="text-indigo-400">{message.user.username}</span>
                  <p class="text-gray-300 mt-1">{message.message}</p>
                </div>
              </div>
            </div>
          </div>

          <!-- Right Sidebar - Users -->
          <div class={["w-64 bg-gray-800 border-l border-gray-700 flex flex-col overflow-hidden", (@sidebar_action == :users || " hidden")]}>
            <div class="px-6 py-4 border-b border-gray-700 font-semibold">Members</div>
            <div class="flex-1 overflow-y-auto px-4 py-4 space-y-2" phx-update="stream" id="users">
              <div :for={{dom_id, presence} <- @streams.presences} id={dom_id} class="flex items-center gap-3 px-3 py-2 rounded hover:bg-gray-700 transition-colors">
                <span class={["w-2 h-2 rounded-full", presence.online && "bg-green-500", !presence.online && "bg-gray-600"]}></span>
                <span class="text-sm">{presence.id}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modals -->
    <div>
      <.raw_modal :if={@modal_action == "server_create_modal"} id="server-create-modal" hide_event="hide_modals">
        <:header>Create New Server</:header>
        <.live_component module={ServerCreateModalComponent} id="chat_server_create_form" modal_id="server-create-modal" current_user={@current_user} />
      </.raw_modal>

      <.raw_modal :if={@modal_action == "channel_create_modal"} id="channel-create-modal" hide_event="hide_modals">
        <:header>Create New Channel</:header>
        <.live_component module={ChannelCreateModalComponent} id="chat_channel_create_form" modal_id="channel-create-modal" current_user={@current_user} selected_server_user={@selected_server_user} />
      </.raw_modal>

      <.raw_modal :if={@modal_action == "find_server_modal"} id="find-server-modal" hide_event="hide_modals">
        <.live_component module={FindServerModalComponent} id="find_server_form" modal_id="find-server-modal" current_user={@current_user} server_users={@server_users} />
      </.raw_modal>
    </div>
    """
  end

  # Handle Server Create Modal Events

  def handle_event("show_server_create_modal", _, socket), do: {:noreply, assign(socket, :modal_action, "server_create_modal")}

  def handle_event("show_find_server_modal", _, socket), do: {:noreply, assign(socket, :modal_action, "find_server_modal")}

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

  def handle_event("prev-page", %{"channel_id" => channel_id, "last_message_id" => last_message_id}, socket) do
    IO.inspect(channel_id, label: "CHANNEL ID")
    case socket.assigns.last_viewport_event + 500_000_000 < System.monotonic_time do
     true ->
        IO.inspect("NOT THROTTLED")
        socket = socket
        |> previous_page({:previous_page, channel_id, last_message_id})
        {:noreply, socket}
      _ ->
        IO.inspect("THROTTLED")
        {:noreply, socket}
    end
  end

  def previous_page(socket, {:previous_page, channel_id, last_message_id}) when is_binary(channel_id) and is_binary(last_message_id) do
    channel_id = String.to_integer(channel_id)
    last_message_id = String.to_integer(last_message_id)

    previous_page(socket, {:previous_page, channel_id, last_message_id})
  end

  def previous_page(socket, {:previous_page, channel_id, last_message_id}) do
    previous_page_messages = Servers.list_channel_messages_previous(channel_id, last_message_id, socket.assigns.message_page_size)

    if(previous_page_messages != []) do
      Enum.reduce(previous_page_messages, socket, fn message, acc_socket ->
        IO.inspect(message, label: "MESSAGE")
        stream_insert(acc_socket, "messages_#{channel_id}", message, at: 0, limit: 2 * socket.assigns.message_page_size)
      end)
      |> assign(:last_viewport_event, System.monotonic_time())
    else
        socket
    end
  end

  def handle_event("next-page", %{"channel_id" => channel_id, "last_message_id" => last_message_id}, socket) do
    case socket.assigns.last_viewport_event + 500_000_000 < System.monotonic_time do
     true ->
        IO.inspect("NOT THROTTLED")
        {:noreply, next_page(socket, {:next_page, channel_id, last_message_id})}
      _ ->
        IO.inspect("THROTTLED")
        {:noreply, socket}
    end
  end

  def next_page(socket, {:next_page, channel_id, last_message_id}) when is_binary(channel_id) and is_binary(last_message_id) do
    channel_id = String.to_integer(channel_id)
    last_message_id = String.to_integer(last_message_id)

    IO.inspect(last_message_id, label: "LAST MESSAGE ID")

    next_page(socket, {:next_page, channel_id, last_message_id})
  end

  def next_page(socket, {:next_page, channel_id, last_message_id}) do
    next_page_messages = Servers.list_channel_messages_next(channel_id, last_message_id, socket.assigns.message_page_size)

    if(next_page_messages != []) do
      Enum.reduce(next_page_messages, socket, fn message, acc_socket ->
        IO.inspect(message, label: "MESSAGE")
        stream_insert(acc_socket, "messages_#{channel_id}", message, at: -1, limit: -2 * socket.assigns.message_page_size)
      end)
      |> assign(:last_viewport_event, System.monotonic_time())
    else
      socket
    end
  end

  # Search history

  def handle_event("search-prev-page", %{"last_message_id" => last_message_id}, socket) do
    IO.inspect("search-prev-page")
    case socket.assigns.last_search_viewport_event + 500_000_000 < System.monotonic_time do
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
    previous_search_page_messages = Servers.search_messages_previous(socket.assigns.search_query, last_message_id, socket.assigns.search_page_size)

    if(previous_search_page_messages != []) do
      Enum.reduce(previous_search_page_messages, socket, fn message, acc_socket ->
        stream_insert(acc_socket, :search_results, message, at: -1, limit: -2 * socket.assigns.search_page_size)
      end)
      |> assign(:last_search_viewport_event, System.monotonic_time())
    else
        socket
    end
  end

  def handle_event("search-next-page", %{"last_message_id" => last_message_id}, socket) do
    case socket.assigns.last_search_viewport_event + 500_000_000 < System.monotonic_time do
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
    IO.inspect("search-next-page")
    next_search_page_messages = Servers.search_messages_next(socket.assigns.search_query, last_message_id, socket.assigns.search_page_size)

    if(next_search_page_messages != []) do
      IO.inspect("search-next-page 2")
      Enum.reduce(next_search_page_messages, socket, fn message, acc_socket ->
        stream_insert(acc_socket, :search_results, message, at: 0, limit: 2 * socket.assigns.search_page_size)
      end)
      |> assign(:last_search_viewport_event, System.monotonic_time())
    else
      socket
    end
  end

  # Handle broadcasts of PubSub events for the server list

  def handle_info(:servers_updated, socket) do
    {:noreply, assign(socket, :server_users, Servers.list_user_server_users(socket.assigns.current_user.id))}
  end

  def handle_info({:channel_created, %Channel{} = channel}, socket) do
    Servers.chat_subscribe(channel.id)

    socket = socket
    |> assign(:channels, Servers.list_server_user_channels(socket.assigns.selected_server_user.server_id))
    |> assign(:selected_channel, channel)
    |> stream("messages_#{channel.id}", [])

    {:noreply, socket}
  end

  def handle_info({:message_created, %Message{} = message}, socket) do

    # Update the last message that will be the relative anchor of our pagination
    bottom_message = Map.get(Map.get(socket.assigns.channel_page_data, message.channel_id, %Message{}), :bottom_message, %Message{})
    ## current_page = Map.get(socket.assigns.channel_page, message.channel_id, 0)

    socket = if !Map.get(bottom_message, :id) || (Map.get(bottom_message, :id, 0) == Map.get(Map.get(Map.get(socket.assigns.channel_page_data, message.channel_id), :bottom_message), :id)) do
      IO.inspect(socket.assigns.channel_page_data, label: "CHANNEL PAGE DATA")

      new_channel_page_data_entry = Map.get(socket.assigns.channel_page_data, message.channel.id, %{})
      |> Map.put(:bottom_message, message)

      new_channel_page_data_entry = if !Map.get(new_channel_page_data_entry, :top_message) do
        Map.put(new_channel_page_data_entry, :top_message, message)
      else
        new_channel_page_data_entry
      end

      socket
      |> stream_insert("messages_#{message.channel.id}", message, at: -1, limit: -2 * socket.assigns.message_page_size)
      |> assign(:channel_page_data, Map.put(socket.assigns.channel_page_data, message.channel.id, new_channel_page_data_entry))
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
    channel_id = Keyword.get(params, :channel_id, nil) # override default channel
    messages = Keyword.get(params, :messages, nil) # messages for the current channel

    # Get what will be the previous selected server user
    %{selected_server_user: previous_selected_server_user } = socket.assigns

    # Unsubcribe from the previous selected server user's channels
    if Map.get(previous_selected_server_user, :id) && connected?(socket) do
      Servers.channel_list_unsubscribe(socket.assigns.current_user.id, socket.assigns.selected_server_user.server_id)

      previous_channels = Servers.list_server_user_channels(previous_selected_server_user.server_id)
      for previous_channel <- previous_channels, do: Servers.chat_unsubscribe(previous_channel.id)
    end

    selected_server_user = Servers.get_server_user!(server_user_id)
    server_users = Servers.list_user_server_users(socket.assigns.current_user.id)
    selected_channel = Servers.get_channel!(if channel_id != nil, do: channel_id, else: selected_server_user.last_selected_channel_id)
    channels = Servers.list_server_user_channels(selected_server_user.server_id)

    users_belonging_to_server = Servers.list_users_belonging_to_server(selected_server_user.server_id)
    presences = for user <- users_belonging_to_server do
      case Presence.get_by_key(presence_topic(), user.id) do
        nil ->
          %{id: user.username, online: false}
        presence ->
          %{id: user.username, online: true}
      end
    end

    socket = stream(socket, :presences, presences, reset: true)

    latest_channel_messages = for channel <- channels, into: %{} do
      {channel.id, Servers.list_latest_channel_messages(channel.id, socket.assigns.message_page_size)}
    end

    channel_page_data = for channel <- channels, into: %{} do
        bottom_message = Map.get(latest_channel_messages, channel.id) |> List.last(%Message{})

        {channel.id, %{
          top_message: Servers.get_channel_first_message(channel.id) || %Message{},
          bottom_message: bottom_message,
        }}
    end

    default_channel = Enum.find(channels, fn channel -> channel.is_default end)

    socket = socket
    |> assign(:modal_action, nil)
    |> assign(:selected_server_user, selected_server_user)
    |> assign(:selected_channel, selected_channel)
    |> assign(:server_users, server_users)
    |> assign(:channels, channels)
    |> assign(:channel_page_data, channel_page_data)
    |> assign(:default_channel_id, Map.get(default_channel, :id, nil))

    socket = Enum.reduce(channels, socket, fn channel, acc_socket ->
      stream(acc_socket, "messages_#{channel.id}", (if selected_channel.id == channel.id && messages != nil, do: messages, else: Map.get(latest_channel_messages, channel.id)), reset: true)
    end)

    if connected?(socket) do
      Servers.channel_list_subscribe(socket.assigns.current_user.id, socket.assigns.selected_server_user.server_id)

      for channel <- channels, do: Servers.chat_subscribe(channel.id)
    end

    socket
  end

  # Handle select server event
  def handle_event("select_channel", %{"channel-id" => channel_id}, socket) do
    channel = Servers.get_channel!(channel_id)

    socket = socket
    |> assign(:selected_channel, channel)
    |> assign(:channels, Servers.list_server_user_channels(socket.assigns.selected_server_user.server_id))

    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket = socket
    |> assign(:sidebar_action, :search)
    |> assign(:search_query, query)
    |> stream(:search_results, Servers.search_messages(query, 40), reset: true)

    {:noreply, socket}
  end

  def update(%{message_uploads: message_uploads} = assigns, socket) do
    changeset = Uploads.change_upload(message_uploads)

    socket = socket
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
    server_user = Servers.get_server_user_by_server_and_user!(message.channel.server_id, socket.assigns.current_user.id)

    socket = socket
    |> select_server_user(server_user.id, channel_id: message.channel.id, messages: Servers.list_channel_messages_from_message_id(message_id, socket.assigns.message_page_size))

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
      user =  Accounts.get_user!(presence.id)
      new_presence = %{
        id: user.username
      }

      IO.inspect(presence.metas, label: "LEFT METAS")

      if presence.metas == [] do
        {:noreply, stream_insert(socket, :presences, Map.put(new_presence, :online, false))}
      else
        {:noreply, stream_insert(socket, :presences, Map.put(new_presence, :online,  true))}
      end
    else
      {:noreply, socket}
    end
  end


  def handle_event("delete_channel", %{"channel_id" => channel_id}, socket) do
    Servers.delete_channel(channel_id)

    Servers.channel_list_broadcast(socket.assigns.current_user.id, socket.assigns.selected_server_user.server_id, {:channel_deleted, channel_id})

    {:noreply, socket}
  end

  def handle_info({:channel_deleted, channel_id}, socket) do
    Servers.chat_unsubscribe(channel_id)

    socket = socket
    |> assign(:channels, Servers.list_server_user_channels(socket.assigns.selected_server_user.server_id))
    |> assign(:channel_page_data, Map.delete(socket.assigns.channel_page_data, channel_id))
    |> stream("messages_#{channel_id}", [], reset: true)

    {:noreply, socket}
  end



  def handle_event("delete_server", %{"server_id" => server_id}, socket) do
    server_id = String.to_integer(server_id)
    users = Servers.list_users_belonging_to_server(server_id)

    Servers.delete_server(server_id)

    IO.inspect(socket.assigns.selected_server_user.server_id, label: "SELECTED SERVER USER SERVER ID")
    IO.inspect(server_id, label: "SERVER ID")

    socket = if socket.assigns.selected_server_user.server_id == server_id do
      socket = Enum.reduce(socket.assigns.channels, socket, fn channel, acc_socket ->
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
