defmodule Tpg.Dominio.Mensajes.Recibido do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recibidos" do
    belongs_to :receptor, Tpg.Dominio.Receptores.Receptor, foreign_key: :receptor_id
    belongs_to :mensaje, Tpg.Dominio.Mensajes.Mensaje, foreign_key: :mensaje_id
  end

  def changeset(attrs) do
    cast(%Tpg.Dominio.Mensajes.Recibido{}, attrs, [:receptor_id, :mensaje_id])
    |> validate_required([:receptor_id, :mensaje_id])
  end
end
