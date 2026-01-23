defmodule Tpg.Receptores.Grupo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "grupos" do
    belongs_to :receptores, Tpg.Receptores.Receptor, foreign_key: :receptor_id, primary_key: true
    field :nombre, :string
    field :descripcion, :string
  end

  def changeset(tipoOperacion, attrs) do
    changeset = cast(%Tpg.Receptores.Grupo{}, attrs, [:receptor_id, :nombre, :descripcion])
    |> IO.inspect()
    case tipoOperacion do
      :crear -> crear_grupo(changeset)
      _ -> {:error, "Operación no soportada"}
    end
  end

  def crear_grupo(changeset) do
    changeset
    |> validate_required([:receptor_id, :nombre])
    |> validate_length(:nombre, min: 8, max: 50)
    |> check_constraint(:nombre, name: "tamanio_nombre", message: "El nombre debe tener entre 8 y 50 caracteres")
    |> validate_length(:descripcion, max: 100)
  end
end
