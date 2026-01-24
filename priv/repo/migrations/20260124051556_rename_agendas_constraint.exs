defmodule Tpg.Repo.Migrations.RenameAgendasConstraint do
  use Ecto.Migration

  def change do
    drop unique_index(:agendas, [:usuario_id, :contacto_id])
    create unique_index(:agendas, [:usuario_id, :contacto_id], name: "agendado_constraint")
  end
end
