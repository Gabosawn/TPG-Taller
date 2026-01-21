defmodule Tpg.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Tpg.Repo,
      {Plug.Cowboy, scheme: :http, plug: Tpg.Router, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: Tpg.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
