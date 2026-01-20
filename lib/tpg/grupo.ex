defmodule Tpg.Grupo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:receptor_id, :id, autogenerate: false}
  schema "grupo" do
    field :nombre, :string
    field :descripcion, :string
    field :cantidad_miembros, :integer

    belongs_to :receptor, Tpg.Receptor, define_field: false, foreign_key: :receptor_id
  end

  def changeset(grupo, attrs) do
    grupo
    |> cast(attrs, [:receptor_id, :nombre, :descripcion, :cantidad_miembros])
    |> validate_required([:receptor_id, :nombre, :cantidad_miembros])
    |> validate_length(:nombre, max: 50)
    |> validate_length(:descripcion, max: 100)
    |> validate_format(:nombre, ~r/^[a-zA-Z0-9]+$/, message: "debe ser alfanumérico")
    |> unique_constraint(:receptor_id, name: :grupo_pkey)
  end
end
