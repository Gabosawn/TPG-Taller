defmodule Tpg do
  require Logger

  def habilitar_canales(id_emisor) do
    grupos = Tpg.Receptores.UsuariosGrupo.get_grupo_ids_by_usuario(id_emisor)
    Logger.info("[tpg] habilitando canales.. ")
    Enum.each(grupos, fn grupo ->
      Logger.info("[tpg] habilitando grupo id #{grupo.id}")
      crear_canal(grupo.id)
    end)
    {:ok, %{id: id_emisor}}
  end

  defp crear_canal(id_grupo) do
    case DynamicSupervisor.start_child(
      Tpg.DynamicSupervisor,
      {Tpg.Runtime.Room, id_grupo}
    ) do
      {:ok, pid} ->
        Logger.info("[tpg] Canal #{id_grupo} creado exitosamente")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("[tpg] Canal #{id_grupo} ya estaba activo")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("[tpg] Error al crear canal #{id_grupo}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def obtener_chats_activos(user_id) do

    usuarios = :global.registered_names()
    Logger.debug("Usuarios activos: #{inspect(usuarios)}")
    usuarios
  end

  def oir_chat(group_id, ws_pid) do
    Logger.info("[tpg] agregando oyente...")
    Tpg.Runtime.Room.agregar_oyente(group_id, ws_pid)
  end

end
