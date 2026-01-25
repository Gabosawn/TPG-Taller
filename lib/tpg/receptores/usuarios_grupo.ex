defmodule Tpg.Receptores.UsuariosGrupo do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key false
  schema "usuarios_grupo" do
    belongs_to :usuarios, Tpg.Receptores.Usuario, foreign_key: :usuario_id, references: :receptor_id, primary_key: true
    belongs_to :grupos, Tpg.Receptores.Grupo, foreign_key: :grupo_id, references: :receptor_id, primary_key: true
  end

  def changeset(tipoOperacion, attrs) do
    changeset = cast(%Tpg.Receptores.UsuariosGrupo{}, attrs, [:usuario_id, :grupo_id])
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

  def get_grupo_ids_by_usuario(emisor_id) do
    from(usuario in Tpg.Receptores.UsuariosGrupo,
      join: grupo in Tpg.Receptores.Grupo,
      on: usuario.grupo_id == grupo.receptor_id,
      where: usuario.usuario_id == ^emisor_id,
      select: %{nombre: grupo.nombre, id: grupo.receptor_id, tipo: "grupo"}
    )
    |> Tpg.Repo.all()
  end
end
