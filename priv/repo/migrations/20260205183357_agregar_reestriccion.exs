defmodule Tpg.Repo.Migrations.AgregarReestriccion do
  use Ecto.Migration

  def change do
    create unique_index(:usuarios_grupo, [:grupo_id, :usuario_id],
             name: :usuarios_grupo_grupo_id_usuario_id_uniq
           )
  end
end
