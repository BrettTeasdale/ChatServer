defmodule ChatServerWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :chat_server,
    pubsub_server: ChatServer.PubSub

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    for {user_id, %{metas: metas}} <- joins do
      presence = %{id: user_id, metas: Map.fetch!(presences, user_id)}

      msg = {:user_joined, presence}

      Phoenix.PubSub.local_broadcast(ChatServer.PubSub, "updates:" <> topic, msg)
    end

    for {user_id, %{metas: metas}} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      presence = %{id: user_id, metas: metas}

      msg = {:user_left, presence}

      Phoenix.PubSub.local_broadcast(ChatServer.PubSub, "updates:" <> topic, msg)
    end

    {:ok, state}
  end
end
