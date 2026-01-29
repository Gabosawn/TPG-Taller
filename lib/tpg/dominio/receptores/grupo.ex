defmodule Tpg.Dominio.Receptores.Grupo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "grupos" do
    belongs_to :receptores, Tpg.Dominio.Receptores.Receptor,
      foreign_key: :receptor_id,
      primary_key: true

    field :nombre, :string
    field :descripcion, :string
  end

  def changeset(attrs) do
    cast(%Tpg.Dominio.Receptores.Grupo{}, attrs, [:receptor_id, :nombre, :descripcion])
    |> validate_required([:receptor_id, :nombre])
    |> validate_length(:nombre, min: 8, max: 50)
    |> check_constraint(:nombre,
      name: "tamanio_nombre",
      message: "El nombre debe tener entre 8 y 50 caracteres"
    )
    |> validate_length(:descripcion, max: 100)
  end
end
