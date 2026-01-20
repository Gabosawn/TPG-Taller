defmodule Tpg.Repo.Migrations.CrearMensajes do
  use Ecto.Migration

  def change do
    create table(:mensajes) do
      add :contenido, :string, null: false
      add :estado, :string, null: false
      timestamps()
    end

    create constraint(:mensajes, :estado_valido, check: "estado IN ('ENVIADO', 'ENTREGADO', 'VISTO')")
  end
end
