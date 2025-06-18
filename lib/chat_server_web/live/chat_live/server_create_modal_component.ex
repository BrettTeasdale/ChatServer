defmodule ChatServerWeb.ChatLive.ServerCreateModalComponent do
  use ChatServerWeb, :live_component

  import ChatServerWeb.CustomComponents

  alias ChatServer.Servers;
  alias ChatServer.Servers.Server;

  def render(assigns) do
    ~H"""
      <div class="{if(!@show_server_create_modal,'hide')}">
        <.raw_modal show={@show_server_create_modal} id="server-create-modal" hide_event="hide_server_create_modal" target={@myself}>
          <:header>Create New Server</:header>
          <.simple_form
            for={@form}
            id="server_create_form"
            phx-submit="save"
            phx-change="validate"
            phx-target={@myself}
          >
            <.error :if={@check_errors}>
              Oops, something went wrong! Please check the errors below.
            </.error>

            <.input field={@form[:name]} type="text" label="Server Name" required />

            <label for="server_name" class="block text-sm font-semibold leading-6 text-zinc-800">Attributes</label>

            <.input field={@form[:private]} type="checkbox" label="Private" />

            <.input field={@form[:description]} type="textarea" label="Description" required />

            <div class="flex shrink-0 flex-wrap items-center pt-4 justify-end">
              <button phx-click="hide_server_create_modal" phx-target={@myself} class="rounded-md border border-transparent py-2 px-4 text-center text-sm transition-all text-slate-600 hover:bg-slate-100 focus:bg-slate-100 active:bg-slate-100 disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none">Cancel</button>
              <.button class="rounded-md bg-green-600 py-2 px-4 border border-transparent text-center text-sm text-white transition-all shadow-md hover:shadow-lg focus:bg-green-700 focus:shadow-none active:bg-green-700 hover:bg-green-700 active:shadow-none disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none ml-2">
                Confirm
              </.button>
            </div>
          </.simple_form>
        </.raw_modal>
      </div>
    """
  end

  def mount(socket) do
    changeset = Servers.change_server(%Server{})

    socket = socket
    |> assign(trigger_submit: false, check_errors: false)
    |> assign(:form, to_form(changeset))
    |> assign(:show_server_create_modal, false)

    #%{current_user: current_user} = socket.assigns
    IO.inspect(socket)

    {:ok, socket}
  end

  def update(%{action: :show_server_create_modal}, socket) do
    {:ok, assign(socket, :show_server_create_modal, true)}
  end

  def update(assigns, socket) do
    socket = socket
    |> assign(:current_user, assigns.current_user)
    |> assign(:modal_id, assigns.modal_id)

    {:ok, socket}
  end

  def handle_event("show_server_create_modal", _, socket) do
    {:noreply, assign(socket, :show_server_create_modal, true)}
  end

  def handle_event("hide_server_create_modal", _, socket) do
    {:noreply, assign(socket, :show_server_create_modal, false)}
  end

  def handle_event("validate", %{"server" => server_params}, socket) do
    changeset = Servers.change_server(%Server{}, server_params)

    {:noreply, assign(socket, :form, to_form(changeset, actions: :validate))}
  end

  def handle_event("save", %{"server" => server_params}, socket) do
    %{current_user: user } = socket.assigns

    case Servers.create_server(user, server_params) do
    {:ok, _server} ->
      changeset = Servers.change_server(%Server{})

      socket = socket
      |> assign(trigger_submit: true)
      |> assign(:form, to_form(changeset))
      |> assign(:show_server_create_modal, false)

      {:noreply, socket}

     {:error, changeset} ->
      {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

end
