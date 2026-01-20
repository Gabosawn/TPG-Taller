defmodule Tpg.Repo.Migrations.InteraccionMensajes do
  use Ecto.Migration

  def change do
    create table(:enviar_mensajes, primary_key: false) do
      add :usuario_id, references(:usuarios, column: :nombre, type: :varchar), primary_key: true, null: false
      add :mensaje_id, references(:mensajes), primary_key: true, null: false
    end

    create table(:recibir_mensajes,  primary_key: false) do
      add :receptor_id, references(:grupos), primary_key: true, null: false
      add :mensaje_id, references(:mensajes), primary_key: true, null: false
    end
  end
end
