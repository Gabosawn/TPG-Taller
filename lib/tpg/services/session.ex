defmodule Tpg.Services.SessionService do
  @moduledoc """
  Session Services module
  """

  require Logger
  alias Tpg.Services.NotificationService
  alias Tpg.Dominio.Receptores
  alias Tpg.Dominio.Receptores.Agendado
  alias Tpg.Services.ChatService
  alias Tpg.Runtime.Session

  @spec loggear(atom(), %{nombre: String.t(), contrasenia: String.t()}) :: {:ok, %{id: integer(), pid: pid()}} | {:error, :invalid_credentials | any()}
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
        {:error, usuario.nombre}
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

  @spec desloggear(non_neg_integer()) :: {:ok, pid()} |{:error, :not_found}
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
    if usuarios == 0 do
      []
    end
    usuarios
  end

  @spec agendar(user_id::integer(), nombre_usuario :: String.t()) :: {:ok, %Agendado{}} | {:error, any()}
  def agendar(user_id, nombre_usuario) do
    case Receptores.agregar_contacto(user_id, nombre_usuario) do
      {:ok, res} ->
        Tpg.habilitar_canales(user_id)
        Logger.info("[session] usuario #{nombre_usuario} agendado correctamente por #{user_id}")
        res = %{
          usuario: %{
            receptor_id: res.usuario.receptor_id,
            nombre: res.usuario.nombre
          },
          contacto: %{
            receptor_id: res.contacto.contacto_id,
            nombre: nombre_usuario
          }
        }
        {:ok, res}
      {:error, motivo} ->
        Logger.warning("[session] #{nombre_usuario} no pudo ser agendado")
        {:error, motivo}
    end
  end

  @spec notificar_mensaje(id_usuario:: integer(), operacion:: atom(), mensaje:: Map, emisor:: integer(), receptor:: integer(), tipo:: String.t())  :: nil
  def notificar_mensaje(id_usuario, operacion, mensaje, emisor, receptor, tipo) do
    with {:ok, pid} <- get_session_pid(id_usuario),
      {:ok, _} <- GenServer.call(pid, {:notificar, operacion, mensaje}) do
        if id_usuario != emisor do
          case {operacion, tipo} do
            {:notificacion_bandeja, "privado"} ->
              if id_usuario != emisor do
                NotificationService.marcar_entregado(mensaje, id_usuario)
                Tpg.Runtime.PrivateRoom.actualizar_estado_mensaje("ENTREGADO", [mensaje.id], id_usuario, emisor)
              end

            {:notificacion_bandeja, "grupo"} ->
              Receptores.marcar_mensaje_entregado(mensaje, id_usuario, receptor)
              Tpg.Runtime.Room.actualizar_estado_mensaje("ENTREGADO", [mensaje.id], id_usuario, receptor)
              #NECESITO VERIFICAR OTRA VEZ SI EL MENSAJE EN SI LO MARCO COMO ENTREGADO

            {:mensaje_nuevo, "privado"} ->
              if id_usuario != emisor do
                NotificationService.marcar_visto(mensaje, id_usuario)
                Tpg.Runtime.PrivateRoom.actualizar_estado_mensaje("VISTO", [mensaje.id], id_usuario, emisor)
              end

            {:mensaje_nuevo, "grupo"} ->
              Receptores.marcar_mensaje_entregado(mensaje, id_usuario, receptor)
              Tpg.Runtime.Room.actualizar_estado_mensaje("ENTREGADO", [mensaje.id], id_usuario, receptor)
              Receptores.marcar_mensaje_visto(mensaje, id_usuario, receptor)
              Tpg.Runtime.Room.actualizar_estado_mensaje("VISTO", [mensaje.id], id_usuario, receptor)
          end
        end
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

  @doc """
  Agrega como listener de una conversacion al usuario en base a su ID. Devuelve el historial de chats de esa conversacion.
  Tipo: ":chat_abierto_privado" o ":chat_abierto_grupo"
  user_id: id de usuario insertandose en la conversacion
  group_id: id de la conversacion a la insertarse
  ws_pid: pid del oyente que busca insertarse
  """
  @spec oir_chat(tipo:: atom(), user_id :: integer(), group_id:: integer(), ws_pid::pid) :: {:ok, [%{}]} | {:ya_esta_escuchando | :error, String.t()}
  def oir_chat(tipo, user_id, group_id, ws_pid) do
    with {:ok, pid} <- get_session_pid(user_id),
         false <- GenServer.call(pid, {:esta_escuchando_canal, group_id}),
         {:ok, mensajes, chat_pid} <- ChatService.mostrar_mensajes(tipo, user_id, group_id) do
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
  @doc """
  Agrega al mapa 'receptor' el campo 'en_linea'
  """
  def agregar_ultima_conexion(receptor) do
    with "privado" <- Map.get(receptor, :tipo),
    {:ok, _} <- get_session_pid(receptor.receptor_id) do
      nuevo_receptor = Map.put(receptor, :en_linea, 1)
      {:ok, nuevo_receptor}
    else
      _ ->
        nuevo_receptor = Map.put(receptor, :en_linea, 0)
        {:ok, nuevo_receptor}
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

  @doc """
  Devuelve true si el usuario está en linea, false si no.
  """
  @spec en_linea?(usuario_id::integer()) :: boolean()
  def en_linea?(usuario_id) do
    case get_session_pid(usuario_id) do
      {:ok, _} -> true
      _ -> false
    end
  end
  @doc """
  Devuelve true si el usuario está escuchando por ese canal, sino false.
  """
  @spec esta_escuchando?(usuario_id::integer(), chat_pid::pid()) :: boolean() | :error
  def esta_escuchando?(usuario_id, chat_pid) do
    case get_session_pid(usuario_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:esta_escuchando_canal, chat_pid})
      _ -> :error
    end
  end
end
