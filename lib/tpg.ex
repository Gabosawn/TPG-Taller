defmodule Tpg do
  require Logger
  alias Tpg.Dominio.Receptores
  alias Tpg.Runtime.{Room, PrivateRoom}

  def habilitar_canales(id_emisor) do
    Logger.info("[tpg] habilitando canales.. ")

    Receptores.get_grupo_ids_by_usuario(id_emisor)
    |> Enum.each(fn grupo ->
      Logger.info("[tpg] habilitando grupo id #{grupo.id}")
      crear_canal_grupal(grupo.id)
    end)

    Receptores.obtener_contactos_agenda(id_emisor)
    |> Enum.each(fn agenda ->
      Logger.info("[tpg] habilitando contacto id #{agenda.nombre}")
      crear_canal_privado(agenda.id, id_emisor)
    end)

    {:ok, %{id: id_emisor}}
  end

  defp crear_canal_grupal(id_grupo) do
    case DynamicSupervisor.start_child(
           Tpg.DynamicSupervisor,
           {Room, id_grupo}
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

  defp crear_canal_privado(usuario_1, usuario_2) do
    case DynamicSupervisor.start_child(
           Tpg.DynamicSupervisor,
           {PrivateRoom, {usuario_1, usuario_2}}
         ) do
      {:ok, pid} ->
        Logger.info("[tpg] Canal #{inspect({usuario_1, usuario_2})} creado exitosamente")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("[tpg] Canal #{inspect({usuario_1, usuario_2})} ya estaba activo")
        {:ok, pid}

      {:error, reason} ->
        Logger.error(
          "[tpg] Error al crear canal #{inspect({usuario_1, usuario_2})}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
