defmodule ChatServerWeb.ChatLive.Index do
  use ChatServerWeb, :live_view

  import ChatServerWeb.CustomComponents

  alias ChatServer.Servers.Server
  alias ChatServer.Servers.ServerUser
  alias ChatServer.Servers.Channel
  alias ChatServer.Servers.Message
  alias ChatServer.Servers.Upload
  alias ChatServer.Servers

  alias ChatServerWeb.ChatLive.ServerCreateModalComponent
  alias ChatServerWeb.ChatLive.ChannelCreateModalComponent
  alias ChatServerWeb.ChatLive.FindServerModalComponent

  on_mount {ChatServerWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do

    if connected?(socket) do
      Servers.server_list_subscribe(socket.assigns.current_user.id)
    end

    channels = []

    socket = socket
    |> assign(:modal_action, nil)
    |> assign(:check_errors, false)
    |> assign(:message_form, to_form(Servers.change_message(%Message{})))
    |> assign(:selected_server_user, %ServerUser{})
    |> assign(:selected_channel, %Channel{})
    |> assign(:server_users, Servers.list_user_servers(socket.assigns.current_user.id))
    |> assign(:channels, channels)
    |> assign(:channel_last_message, %{})
    |> assign(:channel_page_data, %{})
    |> assign(:last_viewport_event, System.monotonic_time())
    |> assign(:message_page_size, 50)
    |> assign(:sidebar_action, :users)
    |> assign(:search_form, to_form(%{}))
    |> stream(:search_results, [])
    |> assign(:last_search_viewport_event, System.monotonic_time())
    |> assign(:search_page_size, 50)
    |> assign(:search_query, "")
    |> allow_upload(:message_uploads, accept: :any, max_entries: 10, auto_upload: false)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed top-0 right-0 left-0" phx-drop-target={@uploads.message_uploads.ref}>
        <div class="float-right mt-0 mb-0 ml-0 mr-8">
          <.simple_form
            for={@search_form}
            id="form"
            phx-submit="search"
            no_margin={true}
          >
          <input type="text" name="query" value="" placeholder="Search..." />
          </.simple_form>
        </div>
      <div class="w-full text-center" :if={Map.get(@selected_server_user, :id)}>
        {@selected_server_user.server.name}
      </div>
      <div class="w-full text-center" :if={!Map.get(@selected_server_user, :id)}>
        Select a Server
      </div>
      <div class="w-full">
        <div class="text-center">
          <h3># {@selected_channel.name}</h3>
        </div>
      </div>
    </div>
    <div class="flex flex-col w-screen h-screen m-0 pl-0 pr-0 pb-0 pt-10">
      <div class="flex flex-row h-full p-0 m-0">
        <div class="h-full w-40 overflow-y-scroll">
          <div>
            <.button phx-click="show_server_create_modal">Create Server</.button>
            <.button phx-click="show_find_server_modal">Find Server</.button>
          </div>
          <%= for {_ref, msg} <- @uploads.message_uploads.errors do %>
            <h3><%= Phoenix.Naming.humanize(msg) %></h3>
          <% end %>
          <%= for entry <- @uploads.message_uploads.entries do %>
            <.live_img_preview entry={entry} width="75" />
            <div class="py-5"><%= entry.progress %>%</div>
          <% end %>

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
          <div class="flex h-full w-full">
          <%= for channel <- @channels do %>
            <div class={["flex flex-1 flex-col w-full h-full channel_view overflow-hidden", (channel.id != Map.get(@selected_channel, :id) && "hidden")]}>
              <div class="flex flex-1 flex-col w-full overflow-y-auto" phx-update="stream" id={"messages_#{channel.id}"} phx-hook={"messageScroll"} data-channel_id={channel.id}>
                <div :for={{dom_id, message} <- @streams["messages_#{channel.id}"]} id={dom_id} data-user={message.user_id} class="message" data-message_id={message.id}>
                  <div class="font-semibold user">
                    {message.user.username}
                  </div>
                  <div class="w-full">
                    {message.message}
                  </div>
                </div>
              </div>
              <div class="w-full" :if={@selected_channel && channel.id == @selected_channel.id}>
                <.simple_form
                  class="flex flex-row w-full m-0 p-0"
                  for={@message_form}
                  id={"server_create_form_#{channel.id}"}
                  phx-submit="send_message"
                  phx-change="validate_message"
                  phx-value-channel-id={@selected_channel.id}
                  no-margin={true}
                >
                  <.live_file_input id={"upload_#{channel.id}"} upload={@uploads.message_uploads} />

                  <div class="flex-1 m-0 w-full">
                    <!--<.input class="w-full p-0 m-0" field={@server_create_form[:name]} type="text" placeholder="Message" />-->
                    <input type="text" name="message[message]" class="m-0 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border-zinc-300 focus:border-zinc-400" placeholder="Message">
                  </div>
                  <div class="w-32 m-0 w-full">
                    <.button class="w-32 m-0">Send Message</.button>
                  </div>
                </.simple_form>
              </div>
            </div>
          <% end %>
            <div class={["flex flex-col w-80 h-full m-0 overflow-y-auto", (@sidebar_action == :search || " hidden")]}>
              Search
              <div class="flex flex-1 flex-col w-full overflow-y-auto" phx-update="stream" id={"search_results"} phx-hook={"searchHistoryScroll"} >
                <div :for={{dom_id, message} <- @streams[:search_results]} id={dom_id} data-channel_id={message.channel_id} class="search_result" data-message_id={message.id} phx-click="select_search_message" phx-value-message_id={message.id}>
                  <div class="font-semibold channel_name">
                    {message.channel.name}
                  </div>
                  <div class="w-full">
                    <span class="user">{message.user.username}</span>
                    <br/>{message.message}
                  </div>
                </div>
              </div>
            </div>
            <div class={["flex flex-col w-80 h-full m-0 overflow-y-scroll", (@sidebar_action == :users || " hidden")]}>
              Users
              <div class="flex-1">
                Users
                <!--
                <div :for={channel <- @channels}>
                  <button phx-click="select_channel" phx-value-channel-id={channel.id} class={@selected_channel && channel.id == @selected_channel.id && "selected"}>
                    # {channel.name}
                  </button>
                </div>
                -->
              </div>
            </div>
          </div>
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

      <.raw_modal :if={@modal_action == "find_server_modal"} id="find-server-modal" hide_event="hide_modals">
        <.live_component module={FindServerModalComponent} id="find_server_form" modal_id="find-server-modal" current_user={@current_user} server_users={@server_users}/>
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
    previous_search_page_messages = Servers.list_previous_search_messages(socket.assigns.search_query, last_message_id, socket.assigns.search_page_size)

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

  def handle_info({:servers_updated}, socket) do
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

    socket = if !Map.get(bottom_message, :id) || (Map.get(bottom_message, :id, 0) == Map.get(Map.get(Map.get(socket.assigns.channel_page_data, message.channel_id), :bottom_message), :id)) do
      IO.inspect("YES")
      socket
      |> stream_insert("messages_#{message.channel.id}", message, at: -1, limit: -2 * socket.assigns.message_page_size)
      #|> assign(:channel_last_message, Map.put(socket.assigns.channel_last_message, message.channel.id, message))
      |> assign(:channel_page_data, Map.put(socket.assigns.channel_page_data, message.channel.id, %{socket.assigns.channel_page_data[message.channel.id] |
        bottom_message: message,
      }))
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
    server_users = Servers.list_user_servers(socket.assigns.current_user.id)
    selected_channel = Servers.get_channel!(if channel_id != nil, do: channel_id, else: selected_server_user.last_selected_channel_id)
    channels = Servers.list_server_user_channels(selected_server_user.server_id)

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

    socket = socket
    |> assign(:modal_action, nil)
    |> assign(:selected_server_user, selected_server_user)
    |> assign(:selected_channel, selected_channel)
    |> assign(:server_users, server_users)
    |> assign(:channels, channels)
    |> assign(:channel_page_data, channel_page_data)

    socket = Enum.reduce(channels, socket, fn channel, acc_socket ->
      stream(acc_socket, "messages_#{channel.id}", (if selected_channel.id == channel_id, do: messages, else: Map.get(latest_channel_messages, channel.id)), reset: true)
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

    IO.inspect(Servers.list_channel_messages_from_message_id(message_id, socket.assigns.message_page_size), label: "MESSAGES1000")

    socket = socket
    |> select_server_user(server_user.id, channel_id: message.channel.id, messages: Servers.list_channel_messages_from_message_id(message_id, socket.assigns.message_page_size))

    {:noreply, socket}
  end

end
