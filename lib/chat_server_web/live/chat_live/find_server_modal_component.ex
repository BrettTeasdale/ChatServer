defmodule ChatServerWeb.ChatLive.FindServerModalComponent do
  use ChatServerWeb, :live_component

  alias ChatServer.Servers;
  alias ChatServer.Servers.Server;

  def render(assigns) do
    ~H"""
      <div id="inner_find_server_form">
        <.simple_form
          for={@form}
          id="search_form"
          phx-submit="search"
          phx-target={@myself}
          no_margin={true}
        >
          <div class="w-full relative">
            <.input field={@form[:query]} type="text" class="w-full px-4 py-3 border-2 border-gray-200 rounded-lg focus:outline-none focus:border-green-500 peer" required />
            <label class="absolute left-2 -top-2.5 px-2 bg-white text-sm text-gray-500 transition-all duration-200
              peer-focus:text-green-500 peer-focus:text-sm
              peer-placeholder-shown:text-base peer-placeholder-shown:top-3.5 peer-placeholder-shown:text-gray-400">
              Search here to find servers
            </label>
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="absolute right-4 top-2.5 text-gray-400">
              <circle cx="11" cy="11" r="8"></circle>
              <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
            </svg>
          </div>
        </.simple_form>

        <div class="flex flex-col overflow-y-auto md:max-h-screen" phx-update="stream" id={"server_search_results"} phx-hook={"findServerScroll"} phx-target={@myself}>
          <div :for={{dom_id, server} <- @streams[:search_results]} id={dom_id} data-server_id={server.id} class="search_result w-full">
            <div class="font-semibold">
              {server.name}
              <%=if Enum.any?(@server_users, fn su -> su.server_id == server.id end) do %>

                <button class="float-right bg-red-500 text-white px-3 py-1 rounded-lg hover:bg-red-600 mt-2"
                  phx-click="leave_server"
                  phx-value-server_id={server.id}
                  phx-target={@myself}>
                  Leave
                </button>
              <% else %>
                <button class="float-right bg-green-500 text-white px-3 py-1 rounded-lg hover:bg-green-600 mt-2"
                  phx-click="join_server"
                  phx-value-server_id={server.id}
                  phx-target={@myself}>
                  Join
                </button>
              <% end %>
            </div>
            <div>
              {server.description}
            </div>
            <hr>
          </div>
        </div>
      </div>
    """
  end

  def mount(socket) do
    changeset = Servers.change_server(%Server{})

    socket = socket
    |> assign(:form, to_form(changeset))
    |> stream(:search_results, [])
    |> assign(:search_page_size, 40)
    |> assign(:query, "")
    |> assign(:last_viewport_event, System.monotonic_time())
    |> assign(:page_size, 20)

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket = socket
    |> assign(:current_user, assigns.current_user)
    |> assign(:server_users, assigns.server_users)

    {:ok, socket}
  end

  def handle_event("search", %{"server" => server_params}, socket) do
    query = Map.get(server_params, "query", "")

    socket = socket
    |> assign(:query, query)
    |> stream(:search_results, Servers.search_servers(query, socket.assigns.search_page_size), reset: true)

    {:noreply, socket}
  end

  # Handle select server event
  def handle_event("leave_server", params, socket) do
    %{"server_id" => server_id} = params

    Servers.leave_server(socket.assigns.current_user.id, server_id)
    Servers.server_list_broadcast(socket.assigns.current_user.id, {:servers_updated})

    server = Servers.get_server!(server_id)

    socket = socket
    |> assign(:server_users, Servers.list_user_servers(socket.assigns.current_user.id))

    {:noreply, stream_insert(socket, :search_results, server)}
  end

  # Handle select server event
  def handle_event("join_server", params, socket) do
    %{"server_id" => server_id} = params

    Servers.join_server(socket.assigns.current_user.id, server_id)
    Servers.server_list_broadcast(socket.assigns.current_user.id, {:servers_updated})

    server = Servers.get_server!(server_id)

    socket = socket
    |> assign(:server_users, Servers.list_user_servers(socket.assigns.current_user.id))

    {:noreply, stream_insert(socket, :search_results, server)}
  end


  def handle_event("prev-page", %{"last_server_id" => last_server_id}, socket) do
    case socket.assigns.last_viewport_event + 500_000_000 < System.monotonic_time do
     true ->
        socket = socket
        |> previous_page({:previous_page, last_server_id})
        {:noreply, socket}
      _ ->
        {:noreply, socket}
    end
  end

  def previous_page(socket, {:previous_page, last_server_id}) when is_binary(last_server_id) do
    last_server_id = String.to_integer(last_server_id)

    previous_page(socket, {:previous_page, last_server_id})
  end

  def previous_page(socket, {:previous_page, last_server_id}) do
    previous_page_servers = Servers.list_previous_servers(socket.assigns.query, last_server_id, socket.assigns.page_size)

    if(previous_page_servers != []) do
      Enum.reduce(previous_page_servers, socket, fn server, acc_socket ->
        stream_insert(acc_socket, :search_results, server, at: 0, limit: 2 * socket.assigns.page_size)
      end)
      |> assign(:last_viewport_event, System.monotonic_time())
    else
        socket
    end
  end

  def handle_event("next-page", %{"last_server_id" => last_server_id}, socket) do
    case socket.assigns.last_viewport_event + 500_000_000 < System.monotonic_time do
     true ->
        IO.inspect("next page")
        {:noreply, next_page(socket, {:next_page, last_server_id})}
      _ ->
        {:noreply, socket}
    end
  end

  def next_page(socket, {:next_page, last_server_id}) when is_binary(last_server_id) do
    last_server_id = String.to_integer(last_server_id)

    next_page(socket, {:next_page, last_server_id})
  end

  def next_page(socket, {:next_page, last_server_id}) do
    next_page_servers = Servers.list_next_servers(socket.assigns.query, last_server_id, socket.assigns.page_size)

    if(next_page_servers != []) do
      Enum.reduce(next_page_servers, socket, fn server, acc_socket ->
        stream_insert(acc_socket, :search_results, server, at: -1, limit: -2 * socket.assigns.page_size)
      end)
      |> assign(:last_viewport_event, System.monotonic_time())
    else
      socket
    end
  end

end
