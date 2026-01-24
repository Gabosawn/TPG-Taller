defmodule Tpg.Services.SessionService do
  """
  Session Services module
  """
  require Logger
  def loggear(typeOp, usuario) do
    Logger.info("Intentando loguear usuario: #{usuario.nombre}")
    case typeOp do
      :crear ->
        case Tpg.Receptores.Cuentas.crear_usuario(usuario) do
          {:ok, usuario_creado} ->
            Logger.info("Usuario #{usuario.nombre} creado en la base de datos")
            crear_proceso(usuario_creado.receptor_id)

          {:error, changeset} ->
            [first_error | _] = changeset.errors
            {field, {message, _opts}} = first_error
            Logger.warning("La creación del usuario #{usuario.nombre} falló: {#{field}: #{message}}")
            {:error, {field, message}}
        end
      :conectar ->
        case Tpg.Receptores.Usuario.changeset(:conectar, usuario) do
          nil ->
            Logger.warning("Usuario #{usuario.nombre} no encontrado o credenciales inválidas")
            {:error, :invalid_credentials}

          {:ok, usuario_encontrado} ->
            Logger.info("Usuario #{usuario.nombre} encontrado en la base de datos")
            Tpg.habilitar_canales(usuario_encontrado.receptor_id) # carga las conversaciones que el usuario puede usar
            crear_proceso(usuario_encontrado.receptor_id) # crea una sesion como usuario
        end
      _ ->
        Logger.warning("Operación desconocida: #{inspect(typeOp)}")
        {:ok, usuario.nombre}
    end
  end

  defp crear_proceso(usuario) do
    case DynamicSupervisor.start_child(
      Tpg.DynamicSupervisor,
      {Tpg.Runtime.Session, usuario}
    ) do
      {:ok, pid} ->
        Logger.info("Usuario #{usuario} logueado exitosamente en ", usuario: usuario)
        {:ok, %{pid: pid, id: usuario}}
      {:error, {:already_started, pid}} ->
        Logger.warning("Usuario #{usuario} ya estaba logueado", usuario: usuario)
        {:error, {:already_started, pid}}
    end
  end

  def desloggear(usuario) do
    Logger.info("Intentando desloguear usuario: #{usuario}")
    case :global.whereis_name(usuario) do
      :undefined ->
        Logger.warning("Usuario #{usuario} no encontrado para desloguear")
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

  def obtener_chats(usuario) do
    Tpg.obtener_chats_activos(usuario.id)

    #[persona (id agenda) | grupo (id grupo)]
  end

  def registrar_sesion(server_pid) do
    ws_pid = self() # el metodo es llamado por un Websocket
    GenServer.call(server_pid, {:registrar_websocket, ws_pid})
  end

end
