# lib/tpg.ex
defmodule Tpg do
  require Logger
  alias Tpg.Services.Chat

  @doc "Punto de entrada único para la mensajería"

  def loggear(typeOp, usuario) do
    Logger.info("Intentando loguear usuario: #{usuario.nombre}")

    #------------------------------------------------------

    case typeOp do
      :crear ->
        case Tpg.Receptores.Cuentas.crear_usuario(usuario) do
          {:ok, usuario_creado} ->
            Logger.info("Usuario #{usuario.nombre} creado en la base de datos")
            crear_proceso(Integer.to_string(usuario_creado.receptor_id))

          {:error, changeset} ->
            [first_error | _] = changeset.errors
            {field, {message, _opts}} = first_error
            Logger.warn("La creación del usuario #{usuario.nombre} falló: {#{field}: #{message}}")
            {:error, {field, message}}
        end
      :conectar ->
        case Tpg.Receptores.Usuario.changeset(:conectar, usuario) do
          nil ->
            Logger.warn("Usuario #{usuario.nombre} no encontrado o credenciales inválidas")
            {:error, :invalid_credentials}

          {:ok, usuario_encontrado} ->
            Logger.info("Usuario #{usuario.nombre} encontrado en la base de datos")
            crear_proceso(Integer.to_string(usuario_encontrado.receptor_id))
        end
      _ ->
        Logger.warn("Operación desconocida: #{inspect(typeOp)}")
        {:ok, usuario.nombre}
    end

    #------------------------------------------------------

  end

  def crear_proceso(usuario) do # Usuario en realidad es el Id y nombre de este %{receptor_id, nombre}
    case DynamicSupervisor.start_child(
      Tpg.DynamicSupervisor,
      {Tpg.Runtime.Server, usuario}
    ) do
      {:ok, pid} ->
        Logger.info("Usuario #{usuario} logueado exitosamente", usuario: usuario, pid: inspect(pid))
        {:ok, %{pid: pid, id: usuario}}
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
