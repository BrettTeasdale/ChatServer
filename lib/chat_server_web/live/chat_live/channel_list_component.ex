defmodule ChatServerWeb.ChatLive.ChannelListComponent do
  use ChatServerWeb, :live_component

  def render(assigns) do
    ~H"""
      <div>
        CHANNEL LIST
      </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end
end
