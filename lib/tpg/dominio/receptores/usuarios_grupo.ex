defmodule Tpg.Dominio.Receptores.UsuariosGrupo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "usuarios_grupo" do
    belongs_to :usuarios, Tpg.Dominio.Receptores.Usuario,
      foreign_key: :usuario_id,
      references: :receptor_id,
      primary_key: true

    belongs_to :grupos, Tpg.Dominio.Receptores.Grupo,
      foreign_key: :grupo_id,
      references: :receptor_id,
      primary_key: true
  end

  def changeset(attrs) do
    cast(%Tpg.Dominio.Receptores.UsuariosGrupo{}, attrs, [:usuario_id, :grupo_id])
    |> validate_required([:usuario_id, :grupo_id], message: "El campo es obligatorio")
  end

end
