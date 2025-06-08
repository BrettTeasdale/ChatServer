defmodule ChatServerWeb.ChatLive.ChatViewComponent do
  use ChatServerWeb, :live_component

  def render(assigns) do
    ~H"""
      <div>
        CHAT VIEW
      </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end
end
