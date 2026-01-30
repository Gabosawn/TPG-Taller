import Config
config :tpg, Tpg.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "tpg_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

  # Logger menos verboso en tests
config :logger, level: :warning

# Otras configuraciones específicas de test
config :tpg,
  websocket_port: 4001  # Puerto diferente para tests
