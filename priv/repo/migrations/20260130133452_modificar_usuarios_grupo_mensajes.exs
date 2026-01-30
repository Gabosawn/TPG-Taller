defmodule Tpg.Repo.Migrations.ModificarUsuariosGrupoMensajes do
  use Ecto.Migration

  def change do
    alter table(:usuarios_grupo) do
      add :ultimo_mensaje_leido, references(:mensajes), null: true
      add :ultimo_mensaje_recibido, references(:mensajes), null: true
    end
  end

  def down do
    alter table(:usuarios_grupo) do
      remove :ultimo_mensaje_leido
      remove :ultimo_mensaje_recibido
    end
  end
end
