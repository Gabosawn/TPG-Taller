defmodule Tpg.Repo.Migrations.AgendarUsuarios do
  use Ecto.Migration

  def change do
    create table(:agendas) do
      add :usuario_id, references(:usuarios, column: :receptor_id, type: :integer), null: false
      add :contacto_id, references(:usuarios, column: :receptor_id, type: :integer), null: false
    end

    create unique_index(:agendas, [:usuario_id, :contacto_id])
  end
end
