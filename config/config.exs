import Config

config :tpg, ecto_repos: [Tpg.Repo]

config :tpg, Tpg.Repo,
  database: "tpg_repo",
  username: "tpg_user",
  password: "tpg_password",
  hostname: "localhost"
