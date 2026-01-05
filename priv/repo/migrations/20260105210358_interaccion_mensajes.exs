defmodule Tpg.Repo.Migrations.InteraccionMensajes do
  use Ecto.Migration

  def change do
    create table("enviar_mensaje", primary_key: false) do
      add :usuario_id, references(:usuario, column: :receptor_id, type: :integer), primary_key: true, null: false
      add :mensaje_id, references(:mensaje), primary_key: true, null: false
    end

    create table("recibir_mensaje",  primary_key: false) do
      add :receptor_id, references(:receptor), primary_key: true, null: false
      add :mensaje_id, references(:mensaje), primary_key: true, null: false
    end
  end
end
