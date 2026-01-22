import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :usuario, :accion]

config :logger,
  level: :debug,
  colors: [enabled: true]

config :tpg, Tpg.Repo,
  database: "tpg_repo",
  username: "tpg_user",
  password: "tpg_password",
  hostname: "localhost"

config :tpg, ecto_repos: [Tpg.Repo]
import_config "#{config_env()}.exs"
