defmodule ChatServerWeb.ChatLive.ServerCreateModalComponent do
  use ChatServerWeb, :live_component

  import ChatServerWeb.CustomComponents

  alias ChatServer.Servers
  alias ChatServer.Servers.Server

  def render(assigns) do
    ~H"""
      <div>
          <.simple_form
            for={@form}
            id="form"
            phx-submit="save"
            phx-change="validate"
            phx-target={@myself}
          >
            <!--<.error :if={@check_errors}>
              Oops, something went wrong! Please check the errors below.
            </.error>
            -->

            <.input field={@form[:name]} type="text" label="Server Name" required />

            <label class="block text-sm font-semibold leading-6">Attributes</label>

            <.input field={@form[:private]} type="checkbox" label="Private" />

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
    changeset = Servers.change_server(%Server{})

    socket = socket
    |> assign(:form, to_form(changeset))
    {:ok, socket}
  end

  def update(assigns, socket) do
    socket = socket
    |> assign(:current_user, assigns.current_user)

    {:ok, socket}
  end

  def handle_event("validate", %{"server" => server_params}, socket) do
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

  def handle_event("save", %{"server" => server_params}, socket) do
    %{current_user: user } = socket.assigns

    case Servers.create_server(user.id, server_params) do
    {:ok, _server_user} ->
      changeset = Servers.change_server(%Server{})

      socket = socket
      |> assign(:form, to_form(changeset))

      Servers.server_list_broadcast(socket.assigns.current_user.id, :servers_updated)

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
