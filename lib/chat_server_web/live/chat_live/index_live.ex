defmodule ChatServerWeb.ChatLive.Index do
  use ChatServerWeb, :live_view

  import ChatServerWeb.CustomComponents

  alias ChatServer.Servers.Server;
  alias ChatServer.Servers.ServerUser;
  alias ChatServer.Servers.Channel;
  alias ChatServer.Servers;

  on_mount {ChatServerWeb.UserAuth, :ensure_authenticated}

  # def update(assigns, socket) do
  #   IO.inspect(assigns)
  #   {:ok, socket}
  # end

  def mount(_params, _session, socket) do

    if connected?(socket) do
      Servers.server_list_subscribe(socket.assigns.current_user.id)
    end

    socket = socket
    |> assign(check_errors: false)
    |> assign(:form, to_form(Servers.change_server(%Server{})))
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
    <div>
      CHAT APP

      <div>
        <.button phx-click="show_server_create_modal">Create Server</.button>
        <.button :if={Map.get(@selected_server_user, :id)} phx-click="show_create_channel_modal">Create Channel</.button>
      </div>

      <.raw_modal :if={@show_server_create_modal} show={@show_server_create_modal} id="server-create-modal" hide_event="hide_server_create_modal">
        <:header>Create New Server</:header>
        <.simple_form
          for={@form}
          id="server_create_form"
          phx-submit="server_create_modal_save"
          phx-change="server_create_modal_validate"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@form[:name]} type="text" label="Server Name" required />

          <label for="server_name" class="block text-sm font-semibold leading-6 text-zinc-800">Attributes</label>

          <.input field={@form[:private]} type="checkbox" label="Private" />

          <.input field={@form[:description]} type="textarea" label="Description" required />

          <div class="flex shrink-0 flex-wrap items-center pt-4 justify-end">
            <button phx-click="hide_server_create_modal" class="rounded-md border border-transparent py-2 px-4 text-center text-sm transition-all text-slate-600 hover:bg-slate-100 focus:bg-slate-100 active:bg-slate-100 disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none">Cancel</button>
            <.button class="rounded-md bg-green-600 py-2 px-4 border border-transparent text-center text-sm text-white transition-all shadow-md hover:shadow-lg focus:bg-green-700 focus:shadow-none active:bg-green-700 hover:bg-green-700 active:shadow-none disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none ml-2">
              Confirm
            </.button>
          </div>
        </.simple_form>
      </.raw_modal>

      <.raw_modal :if={@show_channel_create_modal} show={@show_channel_create_modal} id="channel-create-modal" hide_event="hide_channel_create_modal">
        <:header>Create New Server</:header>
        <.simple_form
          for={@form}
          id="channel_create_form"
          phx-submit="channel_create_modal_save"
          phx-change="channel_create_modal_validate"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@form[:name]} type="text" label="Channel Name" required />

          <label for="channel_name" class="block text-sm font-semibold leading-6 text-zinc-800">Attributes</label>

          <.input field={@form[:private]} type="checkbox" label="Private" />

          <.input field={@form[:is_default]} type="checkbox" label="Is Default" />

          <.input field={@form[:description]} type="textarea" label="Description" required />

          <div class="flex shrink-0 flex-wrap items-center pt-4 justify-end">
            <button phx-click="hide_channel_create_modal" class="rounded-md border border-transparent py-2 px-4 text-center text-sm transition-all text-slate-600 hover:bg-slate-100 focus:bg-slate-100 active:bg-slate-100 disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none">Cancel</button>
            <.button class="rounded-md bg-green-600 py-2 px-4 border border-transparent text-center text-sm text-white transition-all shadow-md hover:shadow-lg focus:bg-green-700 focus:shadow-none active:bg-green-700 hover:bg-green-700 active:shadow-none disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none ml-2">
              Confirm
            </.button>
          </div>
        </.simple_form>
      </.raw_modal>

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
          <button phx-click="select_channel" phx-value-server-id={channel.server_id} class={if channel.id == @selected_channel.id do "selected" end}>
            {channel.name}
          </button>
        </div>
      </div>

      Chat View

      User List

    </div>
    """
  end

  # Handle Server Create Modal Events

  def handle_event("show_server_create_modal", _, socket) do
    {:noreply, assign(socket, :show_server_create_modal, true)}
  end

  def handle_event("hide_server_create_modal", _, socket) do
    {:noreply, assign(socket, :show_server_create_modal, false)}
  end

  def handle_info(:hide_server_create_modal, socket) do
    {:noreply, assign(socket, :show_server_create_modal, false)}
  end

  def handle_event("server_create_modal_validate", %{"server" => server_params}, socket) do
    changeset = Servers.change_server(%Server{}, server_params)

    socket = socket
    |> assign(:form, to_form(changeset, actions: :validate))

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

  # Handle broadcasts of PubSub events for the server list

  def handle_info({:server_created, %ServerUser{} = server_user}, socket) do
    {:noreply, stream_insert(socket, :server_users, server_user, at: 0)}
  end

  def handle_info({:server_removed, %ServerUser{} = server_user}, socket) do
    {:noreply, stream_delete(socket, :servers, server_user)}
  end

  # Handle select server event
  def handle_event("select_server_user", %{"server-user-id" => server_user_id}, socket) do
    # Update the selected server user in the server user stream
    stream_insert(socket, :server_users, socket.assigns.selected_server_user)

    server_user = Servers.get_server_user!(server_user_id)

    socket = socket
    |> stream_insert(:server_users, server_user)
    |> stream(:channels, Servers.list_server_user_channels(server_user), reset: true)


    IO.inspect(server_user);

    {:noreply, assign(socket, :selected_server_user, server_user)}
  end
end
