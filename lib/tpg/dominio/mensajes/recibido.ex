defmodule Tpg.Dominio.Mensajes.Recibido do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recibidos" do
    belongs_to :receptor, Tpg.Dominio.Receptores.Receptor, foreign_key: :receptor_id
    belongs_to :mensaje, Tpg.Dominio.Mensajes.Mensaje, foreign_key: :mensaje_id
  end


  def changeset(recibido, attrs) do
    recibido
    |> cast(attrs, [:mensaje_id, :receptor_id])
    |> validate_required([:mensaje_id, :receptor_id])
    |> foreign_key_constraint(:mensaje_id)
    |> foreign_key_constraint(:receptor_id)
  end

end
