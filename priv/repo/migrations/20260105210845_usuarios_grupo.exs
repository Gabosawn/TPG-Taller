defmodule Tpg.Repo.Migrations.UsuariosGrupo do
  use Ecto.Migration

  def change do
    create table(:usuarios_grupos, primary_key: false) do
      add :usuario_id, references(:usuarios, column: :nombre, type: :varchar), primary_key: true, null: false
      add :grupo_id, references(:grupos), primary_key: true, null: false
    end
  end
end
