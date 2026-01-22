defmodule Tpg.Receptores.UsuariosGrupo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "usuarios_grupo" do
    belongs_to :usuarios, Tpg.Receptores.Usuario, foreign_key: :usuario_id, references: :receptor_id, primary_key: true
    belongs_to :grupos, Tpg.Receptores.Grupo, foreign_key: :grupo_id, references: :receptor_id, primary_key: true
  end

  def changeset(tipoOperacion, attrs) do
    changeset = cast(%Tpg.Receptores.UsuariosGrupo{}, attrs, [:usuario_id, :grupo_id])

    case tipoOperacion do
      :crear -> crear_grupo(changeset)
      _ -> {:error, "Operación no soportada"}
    end
  end

  def crear_grupo(changeset) do
    changeset
    |> validate_required([:usuario_id, :grupo_id], message: "El campo es obligatorio")
  end
end
