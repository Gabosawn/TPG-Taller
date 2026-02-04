import Config
config :tpg, Tpg.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  database: "tpg_repo_test"

  # Logger menos verboso en tests
config :logger, level: :warning

# Otras configuraciones específicas de test
config :tpg,
  websocket_port: 4001  # Puerto diferente para tests
