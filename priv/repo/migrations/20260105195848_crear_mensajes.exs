defmodule Tpg.Repo.Migrations.CrearMensajes do
  use Ecto.Migration

  def change do
    create table(:mensajes) do
      add :contenido, :text, null: false
      add :estado, :varchar, size: 10, null: false, default: "ENVIADO"
      timestamps()
    end

    create constraint(:mensajes, :estado_valido, check: "estado IN ('ENVIADO', 'ENTREGADO', 'VISTO')")
  end
end
