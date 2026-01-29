defmodule Tpg.Services.SessionService do
  """
  Session Services module
  """

  require Logger
  alias Tpg.Dominio.Receptores
  alias Tpg.Dominio.Receptores.Agendado
  alias Tpg.Services.ChatService
  alias Tpg.Runtime.Session

  def loggear(typeOp, usuario) do
    Logger.info("Intentando loguear usuario: #{usuario.nombre}")

    case typeOp do
      :crear ->
        case Receptores.crear_usuario(usuario) do
          {:ok, usuario_creado} ->
            Logger.info("Usuario #{usuario.nombre} creado en la base de datos")
            crear_proceso(usuario_creado.receptor_id)

          {:error, changeset} ->
            [first_error | _] = changeset.errors
            {field, {message, _opts}} = first_error

            Logger.warning(
              "La creación del usuario #{usuario.nombre} falló: {#{field}: #{message}}"
            )

            {:error, {field, message}}
        end

      :conectar ->
        case Receptores.obtener_usuario(usuario) do
          nil ->
            Logger.warning("Usuario #{usuario.nombre} no encontrado o credenciales inválidas")
            {:error, :invalid_credentials}

          {:ok, usuario_encontrado} ->
            Logger.info("Usuario #{usuario.nombre} encontrado en la base de datos")
            crear_proceso(usuario_encontrado.receptor_id)
        end

      _ ->
        Logger.warning("Operación desconocida: #{inspect(typeOp)}")
        {:ok, usuario.nombre}
    end
  end

  defp crear_proceso(usuario) do
    case DynamicSupervisor.start_child(
           Tpg.DynamicSupervisor,
           {Session, usuario}
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

    with {:ok, pid} <- get_session_pid(usuario) do
      DynamicSupervisor.terminate_child(Tpg.DynamicSupervisor, pid)
      Logger.info("Usuario #{usuario} deslogueado exitosamente")
      {:ok, pid}
    else
      _ ->
        Logger.warning("Usuario #{usuario} no encontrado para desloguear")
        {:error, :not_found}
    end
  end

  def obtener_usuarios_activos() do
    usuarios = :global.registered_names()
    Logger.debug("Usuarios activos: #{inspect(usuarios)}")
    usuarios
  end

  @spec agendar(user_id::integer(), nombre_usuario :: String.t()) :: {:ok, %Agendado{}} | {:error, any()}
  def agendar(user_id, nombre_usuario) do
    case Receptores.agregar_contacto(user_id, nombre_usuario) do
      {:ok, res} ->
        Logger.info("[session] usuario #{nombre_usuario} agendado correctamente por #{user_id}")
        {:ok, res}
      {:error, motivo} ->
        Logger.warning("[session] #{nombre_usuario} no pudo ser agendado")
        {:error, motivo}
    end
  end

  def registrar_cliente(session_id, client_pid) do
    with {:ok, pid} <- get_session_pid(session_id),
         :ok <- GenServer.call(pid, {:registrar_websocket, client_pid}) do

      Logger.info("[SESSION SERVICE] cliente registrado con la sesion #{inspect(client_pid)}")
      Tpg.habilitar_canales(session_id)
      {:ok, "[session service] cliente registrado"}
    else
      {:error, _} ->
        Logger.warning("[Session service] no hay sesion con que registrar el cliente")
        {:error, "[session service] no hay sesion con que registrar el cliente"}

      _ ->
        {:error, "[session service] Error: no se pudo registrar el cliente"}
    end
  end

  def mostrar_notificaciones(mensajes, session_id, emisor_id, tipoChat) do
    Logger.debug("[SESSION SERVICE] Mensajes a notificar #{inspect(mensajes)}")
    with {:ok, pid} <- get_session_pid(session_id),
         :ok <- GenServer.cast(pid, {:mostrar_notificaciones, mensajes, emisor_id, tipoChat}) do
      {:ok, "[session service] notificaciones mostradas"}
    else
      {:error, _} ->
        Logger.warning("[Session service] no hay sesion con que mostrar notificaciones")
        {:error, "[session service] no hay sesion con que mostrar notificaciones"}

      _ ->
        {:error, "[session service] Error: no se pudieron mostrar notificaciones"}
    end
  end

  def oir_chat(tipo, user_id, group_id, ws_pid) do
    with {:ok, pid} <- get_session_pid(user_id),
         false <- GenServer.call(pid, {:esta_escuchando_canal, group_id}),
         {:ok, mensajes, chat_pid} <- ChatService.agregar_oyente(tipo, user_id, group_id, ws_pid) do
      Logger.info("[session service] agregando oyente...")
      GenServer.call(pid, {:abrir_chat, chat_pid})
      {:ok, mensajes}
    else
      {:error, message} ->
        {:error, message}

      true ->
        {:ya_esta_escuchando, "La sesion ya esta escuchando este canal"}

      _ ->
        {:error, "[session service] error al oir chat"}
    end
  end

  def get_session_pid(id_usuario) do
    case :global.whereis_name(id_usuario) do
      :undefined ->
        Logger.warning("[Session service] sesion <#{id_usuario}> no encontrada")
        {:error, :undefined}

      pid ->
        {:ok, pid}
    end
  end
end
