defmodule Tpg.Repo.Migrations.CrearReceptor do
  use Ecto.Migration

  def change do
    create table(:receptores, primary_key: false) do
      add :receptor_type, :varchar, size: 10, null: false, primary_key: true
    end

    create unique_index(:receptores, [:receptor_type])
    create constraint(:receptores, :receptor_type, check: "receptor_type IN ('Usuario', 'Grupo')")
  end
end
