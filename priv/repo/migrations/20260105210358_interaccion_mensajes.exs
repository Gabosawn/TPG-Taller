defmodule Tpg.Repo.Migrations.InteraccionMensajes do
  use Ecto.Migration

  def change do
    create table(:enviados) do
      add :usuario_id, references(:usuarios, column: :receptor_id, type: :integer, on_delete: :delete_all), null: false
      add :mensaje_id, references(:mensajes, on_delete: :delete_all), null: false
    end

    create table(:recibidos) do
      add :receptor_id, references(:receptores, on_delete: :delete_all), null: false
      add :mensaje_id, references(:mensajes, on_delete: :delete_all), null: false
    end
  end
end
