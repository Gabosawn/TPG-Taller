# lib/tpg.ex
defmodule Tpg do
  require Logger
  alias Tpg.Services.Chat

  @doc "Punto de entrada único para la mensajería"

  def loggear(usuario) do
    Logger.info("Intentando loguear usuario: #{usuario}")

    case DynamicSupervisor.start_child(
      Tpg.DynamicSupervisor,
      {Tpg.Runtime.Server, usuario}
    ) do
      {:ok, pid} ->
        Logger.info("Usuario #{usuario} logueado exitosamente", usuario: usuario, pid: inspect(pid))
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.warn("Usuario #{usuario} ya estaba logueado", usuario: usuario)
        {:error, {:already_started, pid}}
    end
  end

  def enviar(de, para, msg) do
    Logger.debug("Enviando mensaje de #{inspect(de)} a #{inspect(para)}: #{msg}")
    GenServer.cast(para, {:recibir, de, msg})
  end

  def leer_mensajes(usuario) do
    Logger.debug("Leyendo mensajes de #{inspect(usuario)}")
    GenServer.call(usuario, :ver_historial)
  end

  def desloggear(usuario) do
    Logger.info("Intentando desloguear usuario: #{usuario}")

    case :global.whereis_name(usuario) do
      :undefined ->
        Logger.warn("Usuario #{usuario} no encontrado para desloguear")
        {:error, :not_found}
      pid ->
        DynamicSupervisor.terminate_child(Tpg.DynamicSupervisor, pid)
        Logger.info("Usuario #{usuario} deslogueado exitosamente")
        {:ok, pid}
    end
  end

  def obtener_usuarios_activos() do
    usuarios = :global.registered_names()
    Logger.debug("Usuarios activos: #{inspect(usuarios)}")
    usuarios
  end

  def registrar_websocket(_usuario, server_pid) do
    ws_pid = self() # el metodo es llamado por un Websocket
    GenServer.call(server_pid, {:registrar_websocket, ws_pid})
  end
end
