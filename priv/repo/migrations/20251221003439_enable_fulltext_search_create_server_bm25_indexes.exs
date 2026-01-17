defmodule ChatServer.Repo.Migrations.EnableFulltextSearchCreateServerBm25Indexes do
  use Ecto.Migration

  import Ecto.Query

  alias ChatServer.Repo
  alias ChatServer.Servers.Server

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pg_textsearch"

    alter table(:servers) do
      add :full_text_search, :text
    end

    flush()

    execute "CREATE INDEX servers_full_text_search_bm25 ON servers USING bm25(full_text_search) WITH (text_config='simple')"

    execute "CREATE INDEX messages_full_text_search_bm25 ON server_channel_messages USING bm25(message) WITH (text_config='simple')"

    flush()

    from(
      s in Server,
      update: [
        set: [
          full_text_search: fragment("concat_ws(' ', ?, ?)", s.name, s.description)
        ]
      ]
    )
    |> Repo.update_all([])
  end
end
