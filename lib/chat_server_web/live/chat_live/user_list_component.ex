defmodule ChatServerWeb.ChatLive.UserListComponent do
  use ChatServerWeb, :live_component

  def render(assigns) do
    ~H"""
      <div>
        USER LIST
      </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end
end
