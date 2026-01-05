defmodule Tpg.Repo.Migrations.UsuariosGrupo do
  use Ecto.Migration

  def change do
    create table("usuario_grupo", primary_key: false) do
      add :usuario_id, references(:receptor), primary_key: true, null: false
      add :grupo_id, references(:grupo), primary_key: true, null: false
    end
  end
end
