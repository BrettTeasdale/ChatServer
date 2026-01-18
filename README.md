# Setup the custom PostgreSQL docker container

## Build the custom Postgresql docker container that enables full text search

Run from shell in project root, or run `./build.sh`. You will need to add `sudo` if you are not in the `docker` group.

```
docker build -t postgres-pgtextsearch .
```

## Setup the PostGreSQL & ChatServer `.env` environment variables

These will be used by both docker an our Phoenix app to setup and connect to the PostgreSQL database.

```
POSTGRESQL_USERNAME=<YOUR_USERNAME>
POSTGRESQL_PASSWORD=<YOUR_NEW_PASSWORD>
POSTGRESQL_DATABASE=<YOUR_DATABASE_NAME>
POSTGRESQL_PORT=<PORT_TO_MAP_TO_ON_HOST>
POSTGRESQL_HOSTNAME=<YOUR_DATABASE_NAME>
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
