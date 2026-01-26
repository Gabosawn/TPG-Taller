defmodule Tpg.Repo.Migrations.CrearRecibirYLeerMensajes do
  use Ecto.Migration

  def change do
    alter table(:recibidos) do
      add :recibido_at, :utc_datetime
      add :leido_at, :utc_datetime

      timestamps(updated_at: false)  # Solo inserted_at
    end

    # Un usuario solo puede tener 1 registro de lectura por mensaje
    create unique_index(:recibidos, [:mensaje_id, :receptor_id])

    # Índices para queries rápidas
    create index(:recibidos, [:receptor_id, :leido_at])
    create index(:recibidos, [:mensaje_id])

    create constraint(:recibidos, :orden_eventos,
      check: "leido_at IS NULL OR leido_at >= COALESCE(recibido_at, inserted_at)"
    )
  end
end
