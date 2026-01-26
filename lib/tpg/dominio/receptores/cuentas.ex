defmodule Tpg.Dominio.Receptores.Cuentas do
  @moduledoc """
  Contexto para gestionar usuarios y su receptor asociado.
  """

  alias Tpg.Repo
  alias Ecto.Multi

  def crear_usuario(attrs) do
    Multi.new()
    |> Multi.insert(:receptores, %Tpg.Receptores.Receptor{tipo: "Usuario"})
    |> Multi.insert(:usuarios, fn %{receptores: receptor} ->
      Tpg.Receptores.Usuario.changeset(:crear, Map.put(attrs, :receptor_id, receptor.id))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{usuarios: usuario}} -> {:ok, usuario}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end

  end
  def crear_grupo(attrs_grupo, miembros) do
    multi = Multi.new()
    |> Multi.insert(:receptores, %Tpg.Receptores.Receptor{tipo: "Grupo"})
    |> Multi.insert(:grupos, fn %{receptores: receptor} ->
      Tpg.Receptores.Grupo.changeset(:crear, Map.put(attrs_grupo, :receptor_id, receptor.id))
    end)

    # Agregar cada miembro uno por uno usando Enum.reduce
    multi_con_miembros = Enum.reduce(miembros, multi, fn miembro_id, acc ->
      Multi.insert(acc, {:usuario_grupo, miembro_id}, fn %{grupos: grupo} ->
        Tpg.Receptores.UsuariosGrupo.changeset(:crear, %{
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
