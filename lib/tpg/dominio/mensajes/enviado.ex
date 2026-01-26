defmodule Tpg.Mensajes.Enviado do
  use Ecto.Schema
  import Ecto.Changeset

  schema "enviados" do
    belongs_to :usuario, Tpg.Receptores.Usuario, foreign_key: :usuario_id, references: :receptor_id
    belongs_to :mensaje, Tpg.Mensajes.Mensaje, foreign_key: :mensaje_id
  end

  def changeset(attrs) do
    cast(%Tpg.Mensajes.Enviado{}, attrs, [:usuario_id, :mensaje_id])
    |> validate_required([:usuario_id, :mensaje_id])
    |> foreign_key_constraint(:usuario_id, name: :enviados_usuario_id_fkey, message: "El usuario no existe")
    |> foreign_key_constraint(:mensaje_id, name: :enviados_mensaje_id_fkey, message: "El mensaje no existe")
  end

end
