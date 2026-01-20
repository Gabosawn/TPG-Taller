defmodule Tpg.Repo.Migrations.CrearReceptor do
  use Ecto.Migration

  def change do
    create table(:receptores) do
      add :tipo, :varchar, size: 10, null: false
      timestamps()
    end

    create constraint(:receptores, :tipo_valido, check: "tipo IN ('Usuario', 'Grupo')")
  end
end
