defmodule ChatServer.ServersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ChatServer.Servers` context.
  """

  @doc """
  Generate a server.
  """
  def server_fixture(attrs \\ %{}) do
    {:ok, server} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        private: true
      })
      |> ChatServer.Servers.create_server()

    server
  end
end
