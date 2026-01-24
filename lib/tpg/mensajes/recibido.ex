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
    query = from( r in Tpg.Mensajes.Recibido,
      join: m in Tpg.Mensajes.Mensaje,
      on: r.mensaje_id == m.id,
      join: e in Tpg.Mensajes.Enviado,
      on: m.id == e.mensaje_id,
      where: r.receptor_id == ^grupo_id,
      select: %{
        id: m.id,
        emisor: e.usuario_id,
        contenido: m.contenido,
        estado: m.estado,
        fecha: m.inserted_at
      },
      order_by: [asc: m.inserted_at])
    |> Tpg.Repo.all()
  end

  def get_mensajes_usuarios(user_1, user_2) do

    from( r in Tpg.Mensajes.Recibido,
      join: m in Tpg.Mensajes.Mensaje,
      on: r.mensaje_id == m.id,
      join: e in Tpg.Mensajes.Enviado,
      on: m.id == e.mensaje_id,
      where: ((r.receptor_id == ^user_1 and e.usuario_id == ^user_2) or
              (r.receptor_id == ^user_2 and e.usuario_id == ^user_1)),
      select: %{
        id: m.id,
        emisor: e.usuario_id,
        receptor: r.receptor_id,
        contenido: m.contenido,
        estado: m.estado,
        fecha: m.inserted_at
      },
      order_by: [desc: m.inserted_at])
    |> Tpg.Repo.all()
  end

end
