defmodule Tpg.Dominio.Receptores.Agendado do
  use Ecto.Schema
  import Ecto.Query

  schema "agendas" do
    belongs_to :usuario, Tpg.Dominio.Receptores.Usuario,
      foreign_key: :usuario_id,
      references: :receptor_id

    belongs_to :contacto, Tpg.Dominio.Receptores.Usuario,
      foreign_key: :contacto_id,
      references: :receptor_id
  end
end
