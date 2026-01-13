# Setup the custom PostgreSQL docker container

## Build the custom Postgresql docker container that enables full text search

Run from shell in project root, or run `./build.sh`. You will need to add `sudo` if you are not in the `docker` group.

```
docker build -t postgres-pgtextsearch
```

## Setup the PostGreSQL Environment `.env` variables

```
DOCKER_POSTGRESQL_USERNAME=<YOUR_USERNAME>
DOCKER_POSTGRESQL_PASSWORD=<YOUR_NEW_PASSWORD>
DOCKER_POSTGRESQL_DATABASE=<YOUR_DATABASE_NAME>
DOCKER_POSTGRESQL_PORT=<PORT_TO_MAP_TO_ON_HOST>
```

Start the PostgreSQL server

```
docker-compose up
```

## SELinux Consideration

This will allow SELinux to access the `./pgdata/` directory the host filesystem

```
sudo chcon -Rt svirt_sandbox_file_t ./pgdata/
```

# Configure phoenix

## Configure your Phoenix secrets

Create `./config/dev.secret.exs` and add this code with your postgresql secrets configured in your docker-compose.

```
import Config

config :chat_server, ChatServer.Repo,
  username: "<POSTGRESQL_USERNAME>",
  password: "<POSTGRESQL_PASSWORD>",
  hostname: "localhost",
  database: "<POSTGRESQL_DATABASE_NAME>",
  port: 5432,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```


## Start the Phoenix server

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4002`](http://localhost:4002) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

# How to access the chat page

1. Register for an account at the `/users/register` uri
2. Follow the login link in the upper right or access the uri `/users/log_in` with newly created credentials
3. Go to the `/chat` uri, create server, and begin chatting.
