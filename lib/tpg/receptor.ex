defmodule Tpg.Receptor do
  use Ecto.Schema

  schema "receptor" do
    timestamps()

    has_one :usuario, Tpg.Usuario, foreign_key: :receptor_id
    has_one :grupo, Tpg.Grupo, foreign_key: :receptor_id
  end
end
