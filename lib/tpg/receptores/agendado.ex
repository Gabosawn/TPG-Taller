defmodule Tpg.Receptores.Agendado do
  use Ecto.Schema
  import Ecto.Query

  schema "agendas" do
    belongs_to :usuario, Tpg.Receptores.Usuario, foreign_key: :usuario_id, references: :receptor_id
    belongs_to :contacto, Tpg.Receptores.Usuario, foreign_key: :contacto_id, references: :receptor_id
  end

  def obtener_contactos_agenda(usuario_id) do
    from(agenda in Tpg.Receptores.Agendado,
      join: contacto in Tpg.Receptores.Usuario,
      on: agenda.contacto_id == contacto.receptor_id,
      where: agenda.usuario_id == ^usuario_id,
      select: %{nombre: contacto.nombre, id: contacto.receptor_id, tipo: "privado"}
    )
    |> Tpg.Repo.all()
  end

  def obtener_mensajes(usuario_1, usuario_2) do
    Tpg.Mensajes.Recibido.obtener_mensajes_usuarios(usuario_1, usuario_2)
  end
end
