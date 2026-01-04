defmodule ChatServerWeb.Presence do
  use Phoenix.Presence,
    otp_app: :chat_server,
    pubsub_server: ChatServer.PubSub
end
