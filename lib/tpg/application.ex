defmodule Tpg.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Tpg.Repo,
      {DynamicSupervisor, name: Tpg.DynamicSupervisor, strategy: :one_for_one},
      # Cowboy HTTP con dispatch personalizado
      {Plug.Cowboy,
        scheme: :http,
        plug: Tpg.Router,
        options: [
          port: 4000,
          dispatch: cowboy_dispatch()
        ]
      }
    ]

    opts = [strategy: :one_for_one, name: Tpg.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp cowboy_dispatch do
    [
      {:_, [
        {"/ws", Tpg.WebSocketHandler, []},
        {:_, Plug.Cowboy.Handler, {Tpg.Router, []}}
      ]}
    ]
  end
end
