defmodule ChatServerWeb.ChatLive.Index do
  use ChatServerWeb, :live_view

  alias ChatServerWeb.ChatLive.ServerListComponent
  alias ChatServerWeb.ChatLive.ChannelListComponent
  alias ChatServerWeb.ChatLive.ChatViewComponent
  alias ChatServerWeb.ChatLive.UserListComponent

  on_mount {ChatServerWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <div>
      CHAT APP

      <.live_component module={ServerListComponent} id={:chat_server_list} />

      <.live_component module={ChannelListComponent} id={:chat_channel_list} />

      <.live_component module={ChatViewComponent} id={:chat_view} />

      <.live_component module={UserListComponent} id={:chat_user_list} />

    </div>
    """
  end
end
