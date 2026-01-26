defmodule Tpg.Dominio.Receptores.Agendado do
  use Ecto.Schema
  import Ecto.Query

  schema "agendas" do
    belongs_to :usuario, Tpg.Dominio.Receptores.Usuario, foreign_key: :usuario_id, references: :receptor_id
    belongs_to :contacto, Tpg.Dominio.Receptores.Usuario, foreign_key: :contacto_id, references: :receptor_id
  end

  def obtener_contactos_agenda(usuario_id) do
    from(agenda in Tpg.Dominio.Receptores.Agendado,
      join: contacto in Tpg.Dominio.Receptores.Usuario,
      on: agenda.contacto_id == contacto.receptor_id,
      where: agenda.usuario_id == ^usuario_id,
      select: %{nombre: contacto.nombre, id: contacto.receptor_id, tipo: "privado"}
    )
    |> Tpg.Repo.all()
  end

end
