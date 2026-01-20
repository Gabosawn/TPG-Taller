defmodule Tpg.Repo.Migrations.CrearGrupos do
  use Ecto.Migration

  def change do
    create table(:grupos, primary_key: false) do
      add :receptor_id, references(:receptores), primary_key: true, null: false
      add :nombre, :varchar, size: 50, null: false
      add :descripcion, :string, size: 100, null: true
      add :cantidad_miembros, :integer, null: false
    end

    create constraint(:grupos, :nombre_alfanumerico, check: "nombre ~ '^[a-zA-Z0-9]+$'")
    create constraint(:grupos, :tamanio_nombre, check: "length(nombre) >= 8 AND length(nombre) <= 50")
  end
end
