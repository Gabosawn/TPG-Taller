defmodule Tpg.Repo do
  use Ecto.Repo,
    otp_app: :tpg,
    adapter: Ecto.Adapters.Postgres
end
