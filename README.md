# Tpg

Servicio de mensajeria instantanea Cliente-Servidor usando Cowboy, Ecto y GenServers.

## Setup
Make sure docker is running to run it locally. Then run:

`mix deps.get`
`docker compose up -d`
`mix exto.create`
`mix ecto.migrate`

## Running
`iex -S mix` o `iex.bat -S mix` desde Windows