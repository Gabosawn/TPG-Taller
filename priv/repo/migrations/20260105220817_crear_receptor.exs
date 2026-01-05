defmodule Tpg.Repo.Migrations.CrearReceptor do
  use Ecto.Migration

  def change do
    create table("receptor") do
      add :nombre, :string, size: 50, null: false
      timestamps()
    end

    create constraint("receptor", :nombre_alfanumerico, check: "nombre ~ '^[a-zA-Z0-9]+$'")
  end
end
