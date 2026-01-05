defmodule Tpg.Repo.Migrations.CrearGrupos do
  use Ecto.Migration

  def change do
    create table("grupo", primary_key: false) do
      add :receptor_id, references(:receptor), primary_key: true, null: false
      add :descripcion, :string, size: 100, null: true
      add :cantidad_miembros, :integer, null: false
    end
  end
end
