defmodule Tpg.Repo.Migrations.CrearMensajes do
  use Ecto.Migration

  def change do
    create table("mensaje") do
      add :contenido, :string, size: 300, null: false
      add :estado, :string, size: 10, null: false
      timestamps()
    end

    create constraint("mensaje", :estado_valido, check: "estado IN ('ENVIADO', 'ENTREGADO', 'VISTO')")
  end
end
