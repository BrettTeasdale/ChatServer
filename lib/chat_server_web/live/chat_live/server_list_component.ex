defmodule ChatServerWeb.ChatLive.ServerListComponent do
  use ChatServerWeb, :live_component

  def render(assigns) do
    ~H"""
      <div>
        SERVER LIST
      </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end
end
