defmodule Tpg.Repo.Migrations.UsuariosGrupo do
  use Ecto.Migration

  def change do
    create table(:usuarios_grupo, primary_key: false) do
      add :usuario_id, references(:usuarios, column: :receptor_id, type: :integer), primary_key: true, null: false
      add :grupo_id, references(:grupos, column: :receptor_id, type: :integer), primary_key: true, null: false
    end
  end
end
