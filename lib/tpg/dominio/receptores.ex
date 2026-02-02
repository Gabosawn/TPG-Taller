defmodule Tpg.Dominio.Receptores do
  alias Tpg.Dominio.Receptores.{Agendado, Usuario, Receptor, UsuariosGrupo, Grupo}
  alias Tpg.Repo
  alias Ecto.Multi
  import Ecto.Changeset
  import Ecto.Query

  @moduledoc """
  Contexto para gestionar usuarios y su receptor asociado.
  """

  # --------------------- Usuarios ---------------------
  def obtener_usuarios() do
    Repo.all(
      from u in Usuario,
        select: %{nombre: u.nombre, receptor_id: u.receptor_id}
    )
  end

  def marcar_ultimo_mensaje_visto(mensaje, usuario_id, grupo_id) do
    case Repo.get_by(UsuariosGrupo, usuario_id: usuario_id, grupo_id: grupo_id) do
      nil -> nil
      grupo ->
        grupo
        |> change()
        |> put_change(:ultimo_mensaje_leido, mensaje.id)
        |> Repo.update()
    end

  end

  def obtener_usuario(attrs) do
    case Repo.get_by(Usuario,
           nombre: attrs.nombre,
           contrasenia: attrs.contrasenia
         ) do
      nil ->
        nil

      usuario ->
        usuario
        |> change()
        |> put_change(:ultima_conexion, DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()
    end
  end

  def crear_usuario(attrs) do
    Multi.new()
    |> Multi.insert(:receptores, %Receptor{tipo: "Usuario"})
    |> Multi.insert(:usuarios, fn %{receptores: receptor} ->
      Usuario.changeset(Map.put(attrs, :receptor_id, receptor.id))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{usuarios: usuario}} -> {:ok, usuario}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  def agregar_contacto(id_usuario, nombre_usuario) do
    with {:ok, usuario} <- validar_usuario_existe(id_usuario),
         {:ok, contacto} <- validar_contacto_existe(nombre_usuario),
         {:ok, contacto} <- validar_no_es_si_mismo(id_usuario, contacto),
         {:ok, contacto} <- insertar_contacto(id_usuario, contacto.receptor_id) do
      {:ok, %{usuario: usuario, contacto: contacto}}
    else
      {:error, :usuario_no_existe} ->
        {:error, "El usuario con ID #{id_usuario} no existe"}

      {:error, :contacto_ya_agendado} ->
        {:error, "El usuario con ID #{id_usuario} ya pertenece a la agenda"}

      {:error, :contacto_no_existe} ->
        {:error, "El usuario '#{nombre_usuario}' no existe"}

      {:error, :es_si_mismo} ->
        {:error, "No puede agendarse a si mismo"}

      error ->
        error
    end
  end

  defp validar_usuario_existe(id_usuario) do
    case Repo.get(Usuario, id_usuario) do
      nil -> {:error, :usuario_no_existe}
      usuario -> {:ok, usuario}
    end
  end

  defp validar_contacto_existe(nombre_usuario) do
    case Repo.get_by(Usuario, nombre: nombre_usuario) do
      nil -> {:error, :contacto_no_existe}
      contacto -> {:ok, contacto}
    end
  end

  defp validar_no_es_si_mismo(id_usuario, contacto) do
    if id_usuario == contacto.receptor_id do
      {:error, :es_si_mismo}
    else
      {:ok, contacto}
    end
  end

  defp insertar_contacto(id_usuario, id_contacto) do
    case Repo.get_by(Agendado,
           usuario_id: id_usuario,
           contacto_id: id_contacto
         ) do
      nil ->
        # No existe, proceder con insert
        %Agendado{}
        |> cast(%{usuario_id: id_usuario, contacto_id: id_contacto}, [:usuario_id, :contacto_id])
        |> validate_required([:usuario_id, :contacto_id])
        |> Repo.insert()

      _existing ->
        # Ya existe
        {:error, :contacto_ya_agendado}
    end
  end

  def existe_usuario?(id_usuario) do
    Repo.get(Usuario, id_usuario) != nil
  end

  # --------------------- Grupos ---------------------

  def crear_grupo(attrs_grupo, miembros) do
    multi =
      Multi.new()
      |> Multi.insert(:receptores, %Receptor{tipo: "Grupo"})
      |> Multi.insert(:grupos, fn %{receptores: receptor} ->
        Grupo.changeset(Map.put(attrs_grupo, :receptor_id, receptor.id))
      end)

    # Agregar cada miembro uno por uno usando Enum.reduce
    multi_con_miembros =
      Enum.reduce(miembros, multi, fn miembro_id, acc ->
        Multi.insert(acc, {:usuario_grupo, miembro_id}, fn %{grupos: grupo} ->
          UsuariosGrupo.changeset(%{
            usuario_id: miembro_id,
            grupo_id: grupo.receptor_id
          })
        end)
      end)

    multi_con_miembros
    |> Repo.transaction()
    |> case do
      {:ok, %{grupos: grupo}} ->
        {:ok, grupo}

      {:error, _operation, changeset, _changes} ->
        message = format_changeset_message("Crear grupo", changeset)
        {:error, message}
    end
  end

  defp format_changeset_message(operacion, %Ecto.Changeset{} = changeset) do
    errores =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
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

  def get_grupo_ids_by_usuario(emisor_id) do
    from(usuario in UsuariosGrupo,
      join: grupo in Grupo,
      on: usuario.grupo_id == grupo.receptor_id,
      where: usuario.usuario_id == ^emisor_id,
      select: %{nombre: grupo.nombre, id: grupo.receptor_id, tipo: "grupo"}
    )
    |> Tpg.Repo.all()
  end

  @spec obtener_miembros(group_id:: integer()) :: [integer()]
  def obtener_miembros(group_id) do
  query =
    from(ug in UsuariosGrupo,
      join: u in Usuario, on: ug.usuario_id == u.receptor_id,
      where: ug.grupo_id == ^group_id,
      select: u.receptor_id
    )
  |> Tpg.Repo.all()
  end

  # --------------------- Agenda ---------------------

  def obtener_contactos_agenda(usuario_id) do
    from(agenda in Agendado,
      join: contacto in Usuario,
      on: agenda.contacto_id == contacto.receptor_id,
      where: agenda.usuario_id == ^usuario_id,
      select: %{nombre: contacto.nombre, id: contacto.receptor_id, tipo: "privado"}
    )
    |> Tpg.Repo.all()
  end

  # --------------------- Receptores ---------------------

  def obtener(tipo, receptor_id) do
    resultado = case tipo do
      "grupo" ->
        from(g in Grupo,
          where: g.receptor_id == ^receptor_id,
          select: %{
            nombre: g.nombre,
            receptor_id: g.receptor_id,
            tipo: "grupo",
            descripcion: g.descripcion,
            ultima_conexion: nil
          }
        )
        |> Tpg.Repo.one()

      "privado" ->
        from(u in Usuario,
          where: u.receptor_id == ^receptor_id,
          select: %{
            nombre: u.nombre,
            receptor_id: u.receptor_id,
            tipo: "privado",
            ultima_conexion: u.ultima_conexion,
            descripcion: nil
          }
        )
        |> Tpg.Repo.one()
    end

    case resultado do
      nil -> {:error, :no_encontrado}
      receptor -> {:ok, receptor}
    end
  end

end
