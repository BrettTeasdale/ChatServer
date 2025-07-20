defmodule ChatServerWeb.ChatLive.Index do
  use ChatServerWeb, :live_view

  import ChatServerWeb.CustomComponents

  alias ChatServer.Servers.Server
  alias ChatServer.Servers.ServerUser
  alias ChatServer.Servers.Channel
  alias ChatServer.Servers

  on_mount {ChatServerWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do

    if connected?(socket) do
      Servers.server_list_subscribe(socket.assigns.current_user.id)
    end

    socket = socket
    |> assign(check_errors: false)
    |> assign(:server_create_form, to_form(Servers.change_server(%Server{})))
    |> assign(:channel_create_form, to_form(Servers.change_channel(%Channel{})))
    |> assign(:show_server_create_modal, false)
    |> assign(:show_channel_create_modal, false)
    |> assign(:selected_server_user, %ServerUser{})
    |> assign(:selected_channel, %Channel{})
    |> stream(:server_users, Servers.list_user_servers(socket.assigns.current_user))
    |> stream(:channels, Servers.list_server_user_channels(%ServerUser{}))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""

    <div class="flex flex-row h-screen p-0 m-0">
      <div class="h-full w-40 overflow-y-scroll">
        <div>
          <.button phx-click="show_server_create_modal">Create Server</.button>
        </div>
        <div phx-update="stream" id="server_list">
          <div :for={{dom_id, server_user} <- @streams.server_users} id={dom_id}>
            <button phx-click="select_server_user" phx-value-server-user-id={server_user.id} class={if server_user.id == @selected_server_user.id do "selected" end}>
              {server_user.server.name}
            </button>
          </div>
        </div>
      </div>

      <div class="flex flex-col w-80 h-screen m-0 overflow-y-scroll">
        <div :if={Map.get(@selected_server_user, :id)}>
          <.button phx-click="show_channel_create_modal">Create Channel</.button>
        </div>
        <div class="flex-1" id="channel_list" phx-update="stream">
          <div :for={{dom_id, channel} <- @streams.channels} id={dom_id}>
            <button phx-click="select_channel" phx-value-channel-id={channel.id} class={if channel.id == @selected_channel.id do "selected" end}>
              # {channel.name}
            </button>
          </div>
        </div>
      </div>

      <div class="flex flex-col w-full h-screen">
        <div class="flex flex-row">
          <div>
            <h3># {@selected_channel.name}</h3>
          </div>
          <div>
            <input type="text" name="query" value="" placeholder="Search..." />
          </div>
        </div>

        <div phx-update="stream" id="chat_view">
          <div :for={{dom_id, channel} <- @streams.channels} id={dom_id} class={"channel_view" <> if channel.id != Map.get(@selected_channel, :id), do: " hidden", else: ""}>
            Channel Name: {channel.name}
            <br>Selected: {channel.id == Map.get(@selected_channel, :id)}
          </div>
        </div>
      </div>
    </div>

    <div>

      <!--
      CHAT APP

      <div>
        <.button phx-click="show_server_create_modal">Create Server</.button>
      </div>
      -->

      <.raw_modal :if={@show_server_create_modal} show={@show_server_create_modal} id="server-create-modal" hide_event="hide_server_create_modal">
        <:header>Create New Server</:header>
        <.simple_form
          for={@server_create_form}
          id="server_create_form"
          phx-submit="server_create_modal_save"
          phx-change="server_create_modal_validate"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@server_create_form[:name]} type="text" label="Server Name" required />

          <label class="block text-sm font-semibold leading-6 text-zinc-800">Attributes</label>

          <.input field={@server_create_form[:private]} type="checkbox" label="Private" />

          <.input field={@server_create_form[:description]} type="textarea" label="Description" required />

          <div class="flex shrink-0 flex-wrap items-center pt-4 justify-end">
            <button phx-click="hide_server_create_modal" class="rounded-md border border-transparent py-2 px-4 text-center text-sm transition-all text-slate-600 hover:bg-slate-100 focus:bg-slate-100 active:bg-slate-100 disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none">Cancel</button>
            <.button class="rounded-md bg-green-600 py-2 px-4 border border-transparent text-center text-sm text-white transition-all shadow-md hover:shadow-lg focus:bg-green-700 focus:shadow-none active:bg-green-700 hover:bg-green-700 active:shadow-none disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none ml-2">
              Confirm
            </.button>
          </div>
        </.simple_form>
      </.raw_modal>

      <.raw_modal :if={@show_channel_create_modal} show={@show_channel_create_modal} id="channel-create-modal" hide_event="hide_channel_create_modal">
        <:header>Create New Channel</:header>
        <.simple_form
          for={@channel_create_form}
          id="channel_create_form"
          phx-submit="channel_create_modal_save"
          phx-change="channel_create_modal_validate"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@channel_create_form[:name]} type="text" label="Channel Name" required />

          <label class="block text-sm font-semibold leading-6 text-zinc-800">Attributes</label>

          <.input field={@channel_create_form[:needs_owner]} type="checkbox" label="Requires Owner" />

          <.input field={@channel_create_form[:needs_operator]} type="checkbox" label="Requires Operator" />

          <.input field={@channel_create_form[:needs_voiced]} type="checkbox" label="Requires Voiced" />

          <.input field={@channel_create_form[:is_default]} type="checkbox" label="Is Default" />

          <.input field={@channel_create_form[:description]} type="textarea" label="Description" required />

          <div class="flex shrink-0 flex-wrap items-center pt-4 justify-end">
            <button phx-click="hide_channel_create_modal" class="rounded-md border border-transparent py-2 px-4 text-center text-sm transition-all text-slate-600 hover:bg-slate-100 focus:bg-slate-100 active:bg-slate-100 disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none">Cancel</button>
            <.button class="rounded-md bg-green-600 py-2 px-4 border border-transparent text-center text-sm text-white transition-all shadow-md hover:shadow-lg focus:bg-green-700 focus:shadow-none active:bg-green-700 hover:bg-green-700 active:shadow-none disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none ml-2">
              Confirm
            </.button>
          </div>
        </.simple_form>
      </.raw_modal>
      <!--
      <h1>Servers</h1>
      <div phx-update="stream" id="server_list">
        <div :for={{dom_id, server_user} <- @streams.server_users} id={dom_id}>
          <button phx-click="select_server_user" phx-value-server-user-id={server_user.id} class={if server_user.id == @selected_server_user.id do "selected" end}>
            {server_user.server.name}
          </button>
        </div>
      </div>

      <h1>Channels</h1>
      <div phx-update="stream" id="channel_list">
        <div :for={{dom_id, channel} <- @streams.channels} id={dom_id}>
          <button phx-click="select_channel" phx-value-channel-id={channel.id} class={if channel.id == @selected_channel.id do "selected" end}>
            {channel.name}
          </button>
        </div>
      </div>

      <h1>Chat View</h1>
      <div id="chat_view" phx-update="stream" id="chat_view">
        <div :for={{dom_id, channel} <- @streams.channels} id={dom_id} class={"channel_view" <> if channel.id != Map.get(@selected_channel, :id), do: " hidden", else: ""}>
          Channel Name: {channel.name}
          <br>Selected: {channel.id == Map.get(@selected_channel, :id)}
        </div>
      </div>

      User List

      -->
    </div>
    """
  end

  # Handle Server Create Modal Events

  def handle_event("show_server_create_modal", _, socket) do
    {:noreply, assign(socket, :show_server_create_modal, true)}
  end

  def handle_event("show_channel_create_modal", _, socket) do
    {:noreply, assign(socket, :show_channel_create_modal, true)}
  end

  def handle_event("hide_server_create_modal", _, socket) do
    {:noreply, assign(socket, :show_server_create_modal, false)}
  end

  def handle_event("hide_channel_create_modal", _, socket) do
    {:noreply, assign(socket, :show_channel_create_modal, false)}
  end

  def handle_info(:hide_server_create_modal, socket) do
    {:noreply, assign(socket, :show_server_create_modal, false)}
  end

  def handle_event("server_create_modal_validate", %{"server" => server_params}, socket) do
    changeset = Servers.change_server(%Server{}, server_params)

    socket = socket
    |> assign(:server_create_form, to_form(changeset, actions: :validate))

    case changeset.valid? do
      true ->
        assign(socket, :check_errors, false)
        {:noreply, socket}
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("channel_create_modal_validate", %{"channel" => server_params} = test, socket) do
    changeset = Servers.change_channel(%Channel{}, server_params)

    socket = socket
    |> assign(:channel_create_form, to_form(changeset, actions: :validate))

    case changeset.valid? do
      true ->
        assign(socket, :check_errors, false)
        {:noreply, socket}
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("server_create_modal_save", %{"server" => server_params}, socket) do
    %{current_user: user } = socket.assigns

    case Servers.create_server(user, server_params) do
    {:ok, server_user} ->
      changeset = Servers.change_server(%Server{})

      socket = socket
      |> assign(:form, to_form(changeset))
      |> assign(:show_server_create_modal, false)

      IO.inspect(server_user)

      Servers.server_list_broadcast(socket.assigns.current_user.id, {:server_created, server_user})

      {:noreply, socket}

     {:error, changeset} ->
      socket = socket
      |> assign(:form, to_form(changeset))
      |> assign(:check_errors, true)

      {:noreply, socket}
    end
  end

  def handle_event("channel_create_modal_save", %{"channel" => channel_params}, socket) do
    %{selected_server_user: selected_server_user } = socket.assigns

    channel_params = Map.put(channel_params, "server_id", selected_server_user.server_id)

    case Servers.create_channel(selected_server_user, channel_params) do
    {:ok, channel} ->
      changeset = Servers.change_channel(%Channel{})

      socket = socket
      |> assign(:channel_create_form, to_form(changeset))
      |> assign(:show_channel_create_modal, false)

      IO.inspect(channel)

      Servers.channel_list_broadcast(socket.assigns.current_user.id, selected_server_user.server_id, {:channel_created, channel})

      {:noreply, socket}

     {:error, changeset} ->
      socket = socket
      |> assign(:form, to_form(changeset))
      |> assign(:check_errors, true)

      {:noreply, socket}
    end
  end

  # Handle broadcasts of PubSub events for the server list

  def handle_info({:server_created, %ServerUser{} = server_user}, socket) do
    {:noreply, stream_insert(socket, :server_users, server_user, at: 0)}
  end

  def handle_info({:channel_created, %Channel{} = channel}, socket) do
    {:noreply, stream_insert(socket, :channels, channel, at: 0)}
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
    end

    server_user = Servers.get_server_user!(server_user_id)
    channels = Servers.list_server_user_channels(server_user)
    IO.inspect(server_user.server.name)

    socket = socket
    |> assign(:selected_server_user, server_user)
    |> assign(:selected_channel, server_user.last_selected_channel)
    |> stream_insert(:server_users, server_user)
    |> stream(:channels, channels, reset: true)

    socket = if Map.get(previous_selected_server_user, :id) do
      stream_insert(socket, :server_users, previous_selected_server_user)
    else
      socket
    end

    Servers.channel_list_subscribe(socket.assigns.current_user.id, socket.assigns.selected_server_user.server_id)

    IO.inspect(server_user)

    {:noreply, socket}
  end

  # Handle select server event
  def handle_event("select_channel", %{"channel-id" => channel_id}, socket) do
    # Select the current selected channel to update in the channels stream
    previous_selected_channel = socket.assigns.selected_channel

    channel = Servers.get_channel!(channel_id)

    socket = socket
    |> assign(:selected_channel, channel)
    |> stream_insert(:channels, previous_selected_channel)
    |> stream_insert(:channels, channel)

    {:noreply, socket}
  end
end
