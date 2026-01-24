defmodule Tpg.Receptores.Agendado do
  use Ecto.Schema

  schema "agendas" do
    belongs_to :usuario, Tpg.Receptores.Usuario, foreign_key: :usuario_id, references: :receptor_id
    belongs_to :contacto, Tpg.Receptores.Usuario, foreign_key: :contacto_id, references: :receptor_id
  end
end
