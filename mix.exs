defmodule Tpg.MixProject do
  use Mix.Project

  def project do
    [
      app: :tpg,
      version: "0.6.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :cowboy],
      mod: {Tpg.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:plug_cowboy, "~> 2.0"},
      {:jason, "~> 1.2"},
    ]
  end

  defp aliases do
    [
      setup_db: [" ecto.create ", " ecto.migrate"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      reset_db: ["ecto.rollback --all", "ecto.migrate --quiet"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
