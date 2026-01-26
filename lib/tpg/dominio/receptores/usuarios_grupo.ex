defmodule Tpg.Dominio.Receptores.UsuariosGrupo do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key false
  schema "usuarios_grupo" do
    belongs_to :usuarios, Tpg.Dominio.Receptores.Usuario, foreign_key: :usuario_id, references: :receptor_id, primary_key: true
    belongs_to :grupos, Tpg.Dominio.Receptores.Grupo, foreign_key: :grupo_id, references: :receptor_id, primary_key: true
  end

  def changeset(tipoOperacion, attrs) do
    changeset = cast(%Tpg.Dominio.Receptores.UsuariosGrupo{}, attrs, [:usuario_id, :grupo_id])
    |> IO.inspect()
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
