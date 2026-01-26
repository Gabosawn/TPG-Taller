defmodule Tpg.Dominio.Receptores do
  alias Tpg.Dominio.Receptores.{Agendado, Usuario, Receptor, UsuariosGrupo, Grupo}
  alias Tpg.Repo
  alias Ecto.Multi
  import Ecto.Query
  @moduledoc """
  Contexto para gestionar usuarios y su receptor asociado.
  """

  def obtener_contactos_agenda(usuario_id) do
    from(agenda in Agendado,
      join: contacto in Usuario,
      on: agenda.contacto_id == contacto.receptor_id,
      where: agenda.usuario_id == ^usuario_id,
      select: %{nombre: contacto.nombre, id: contacto.receptor_id, tipo: "privado"}
    )
    |> Tpg.Repo.all()
  end

  def crear_usuario(attrs) do
    Multi.new()
    |> Multi.insert(:receptores, %Receptor{tipo: "Usuario"})
    |> Multi.insert(:usuarios, fn %{receptores: receptor} ->
      Usuario.changeset(:crear, Map.put(attrs, :receptor_id, receptor.id))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{usuarios: usuario}} -> {:ok, usuario}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  def crear_grupo(attrs_grupo, miembros) do
    multi = Multi.new()
    |> Multi.insert(:receptores, %Receptor{tipo: "Grupo"})
    |> Multi.insert(:grupos, fn %{receptores: receptor} ->
      Grupo.changeset(:crear, Map.put(attrs_grupo, :receptor_id, receptor.id))
    end)

    # Agregar cada miembro uno por uno usando Enum.reduce
    multi_con_miembros = Enum.reduce(miembros, multi, fn miembro_id, acc ->
      Multi.insert(acc, {:usuario_grupo, miembro_id}, fn %{grupos: grupo} ->
        UsuariosGrupo.changeset(:crear, %{
          usuario_id: miembro_id,
          grupo_id: grupo.receptor_id
        })
      end)
    end)

    multi_con_miembros
    |> Repo.transaction()
    |> case do
      {:ok, %{grupos: grupo}} -> {:ok, grupo}
      {:error, _operation, changeset, _changes} ->
        message = format_changeset_message("Crear grupo", changeset)
        {:error, message}
    end
  end

  def get_grupo_ids_by_usuario(emisor_id) do
    from(usuario in UsuariosGrupo,
      join: grupo in Grupo,
      on: usuario.grupo_id == grupo.receptor_id,
      where: usuario.usuario_id == ^emisor_id,
      select: %{nombre: grupo.nombre, id: grupo.receptor_id, tipo: "grupo"}
    )
    |> Tpg.Repo.all()
  end

  def obtener_usuarios() do
    Usuario.changeset(:listar, %{})
  end

  def existe_usuario?(id_usuario) do
    Repo.get(Usuario, id_usuario) != nil
  end

  defp format_changeset_message(operacion, %Ecto.Changeset{} = changeset) do
    errores = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)

    errores_formateados =
      errores
      |> Enum.map(fn {campo, msgs} ->
        "#{campo}: #{Enum.join(msgs, ", ")}"
      end)
      |> Enum.join("; ")

    "Error en operación #{inspect(operacion)}: #{errores_formateados}"
  end

end
