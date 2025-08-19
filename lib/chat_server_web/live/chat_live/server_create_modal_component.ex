defmodule ChatServerWeb.ChatLive.ServerCreateModalComponent do
  use ChatServerWeb, :live_component

  alias ChatServer.Servers
  alias ChatServer.Servers.Server

  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="create-server-form"
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
      >
        <.input field={@form[:name]} type="text" label="Server Name" required />

        <label class="block text-sm font-semibold leading-6 text-zinc-800">Attributes</label>

        <.input field={@form[:private]} type="checkbox" label="Private" />

        <.input field={@form[:description]} type="textarea" label="Description" required />

        <div class="flex shrink-0 flex-wrap items-center pt-4 justify-end">
          <button
            phx-click={JS.patch(~p"/chat")}
            class="rounded-md border border-transparent py-2 px-4 text-center text-sm transition-all text-slate-600 hover:bg-slate-100 focus:bg-slate-100 active:bg-slate-100 disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none"
          >
            Cancel
          </button>
          <.button class="rounded-md bg-green-600 py-2 px-4 border border-transparent text-center text-sm text-white transition-all shadow-md hover:shadow-lg focus:bg-green-700 focus:shadow-none active:bg-green-700 hover:bg-green-700 active:shadow-none disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none ml-2">
            Confirm
          </.button>
        </div>
      </.simple_form>
    </div>
    """
  end

  def mount(socket) do
    form =
      %Server{}
      |> Servers.change_server()
      |> to_form()

    {:ok, assign(socket, :form, form)}
  end

  def handle_event("validate", %{"server" => server_params}, socket) do
    form =
      %Server{}
      |> Servers.change_server(server_params)
      |> to_form()
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"server" => server_params}, socket) do
    case Servers.create_server(socket.assigns.current_user, server_params) do
      {:ok, server_user} ->
        Servers.server_list_broadcast(
          socket.assigns.current_user.id,
          {:server_created, server_user}
        )

        {:noreply, push_patch(socket, to: ~p"/chat")}

      {:error, changeset} ->
        form =
          changeset
          |> to_form()
          |> Map.put(:action, :save)

        {:noreply, assign(socket, :form, form)}
    end
  end
end
