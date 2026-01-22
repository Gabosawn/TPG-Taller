defmodule Tpg.Repo.Migrations.CrearGrupos do
  use Ecto.Migration

  def change do
    create table(:grupos, primary_key: false) do
      add :receptor_id, references(:receptores), primary_key: true, null: false
      add :nombre, :varchar, size: 50, null: false
      add :descripcion, :varchar, size: 100, null: true
    end

    create constraint(:grupos, :tamanio_nombre, check: "length(nombre) >= 8 AND length(nombre) <= 50")
  end
end
