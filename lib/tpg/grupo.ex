defmodule Tpg.Grupo do
  use Ecto.Schema

  schema "grupos" do
    field :nombre, :string
    field :descripcion, :string
    field :cantidad_miembros, :integer
    belongs_to :receptores, Tpg.Receptor, foreign_key: :receptor_type
  end
end
