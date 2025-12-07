defmodule ChatServerWeb.ChatLive.ChannelCreateModalComponent do
  use ChatServerWeb, :live_component

  import ChatServerWeb.CustomComponents

  alias ChatServer.Servers;
  alias ChatServer.Servers.Channel;

  def render(assigns) do
    ~H"""
      <div>
          <.simple_form
            for={@form}
            id="search_form"
            phx-submit="save"
            phx-change="validate"
            phx-target={@myself}
          >
            <!--<.error :if={@check_errors}>
              Oops, something went wrong! Please check the errors below.
            </.error>-->

            <.input field={@form[:name]} type="text" label="Channel Name" required />

            <label class="block text-sm font-semibold leading-6 text-zinc-800">Attributes</label>

            <.input field={@form[:needs_owner]} type="checkbox" label="Requires Owner" />

            <.input field={@form[:needs_operator]} type="checkbox" label="Requires Operator" />

            <.input field={@form[:needs_voiced]} type="checkbox" label="Requires Voiced" />

            <.input field={@form[:is_default]} type="checkbox" label="Is Default" />

            <.input field={@form[:description]} type="textarea" label="Description" required />

            <div class="flex shrink-0 flex-wrap items-center pt-4 justify-end">
              <button phx-click="hide_modals" class="rounded-md border border-transparent py-2 px-4 text-center text-sm transition-all text-slate-600 hover:bg-slate-100 focus:bg-slate-100 active:bg-slate-100 disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none">Cancel</button>
              <.button class="rounded-md bg-green-600 py-2 px-4 border border-transparent text-center text-sm text-white transition-all shadow-md hover:shadow-lg focus:bg-green-700 focus:shadow-none active:bg-green-700 hover:bg-green-700 active:shadow-none disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none ml-2">
                Confirm
              </.button>
            </div>
          </.simple_form>
      </div>
    """
  end

  def mount(socket) do
    changeset = Servers.change_channel(%Channel{})

    socket = socket
    |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket = socket
    |> assign(:current_user, assigns.current_user)
    |> assign(:selected_server_user, assigns.selected_server_user)

    {:ok, socket}
  end

  def handle_event("validate", %{"channel" => channel_params}, socket) do
    changeset = Servers.change_channel(%Channel{}, channel_params)

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

  def handle_event("save", %{"channel" => channel_params}, socket) do
    %{selected_server_user: selected_server_user } = socket.assigns

    case Servers.create_channel(selected_server_user.server_id, channel_params) do
      {:ok, channel} ->
        changeset = Servers.change_channel(%Channel{})

        socket = socket
        |> assign(:form, to_form(changeset))

        IO.inspect(channel)

        Servers.channel_list_broadcast(socket.assigns.current_user.id, selected_server_user.server_id, {:channel_created, channel})

        send(self(), "hide_modals")

        {:noreply, socket}

      {:error, changeset} ->
        socket = socket
        |> assign(:form, to_form(changeset))
        |> assign(:check_errors, true)

        {:noreply, socket}
    end
  end

end
