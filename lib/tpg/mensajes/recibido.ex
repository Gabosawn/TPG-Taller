defmodule Tpg.Mensajes.Recibido do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "recibidos" do
    belongs_to :receptor, Tpg.Receptores.Receptor, foreign_key: :receptor_id
    belongs_to :mensaje, Tpg.Mensajes.Mensaje, foreign_key: :mensaje_id
  end

  def changeset(attrs) do
    cast(%Tpg.Mensajes.Recibido{}, attrs, [:receptor_id, :mensaje_id])
    |> validate_required([:receptor_id, :mensaje_id])

  end

  def get_mensajes(grupo_id) do
    query = from( receptor in Tpg.Mensajes.Recibido,
      join: mensaje in Tpg.Mensajes.Mensaje, on: receptor.mensaje_id == mensaje.id,
      join: emisor in Tpg.Mensajes.Enviado, on: mensaje.id == emisor.mensaje_id,
      where: receptor.receptor_id == ^grupo_id,
      select: %{
        id: mensaje.id,
        emisor: emisor.usuario_id,
        contenido: mensaje.contenido,
        estado: mensaje.estado,
        fecha: mensaje.inserted_at
      },
      order_by: [desc: mensaje.inserted_at])
    |> Tpg.Repo.all()
  end

  def obtener_mensajes_usuarios(user_1, user_2) do
    mensajes_query = from(mensaje in Tpg.Mensajes.Mensaje,
      join: receptor in Tpg.Mensajes.Recibido, on: mensaje.id == receptor.mensaje_id,
      join: emisor in Tpg.Mensajes.Enviado, on: mensaje.id == emisor.mensaje_id,
      where:
        (receptor.receptor_id == ^user_1 and emisor.usuario_id == ^user_2) or
        (receptor.receptor_id == ^user_2 and emisor.usuario_id == ^user_1),
      select: %{
        id: mensaje.id,
        emisor: emisor.usuario_id,
        contenido: mensaje.contenido,
        estado: mensaje.estado,
        fecha: mensaje.inserted_at
      },
      order_by: [desc: mensaje.inserted_at]
    )
    Tpg.Repo.all(mensajes_query)
    |> IO.inspect(label: "AQQQQQQQQQQQQUUUUUUUUUUUUUUUUUUUIIIIIIIIIIII---------------------------------------")
  end
end
