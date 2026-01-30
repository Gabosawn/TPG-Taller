defmodule Tpg.WebSocketHandler do
  @behaviour :cowboy_websocket
  require Logger
  alias Tpg.Services.ChatService
  alias Tpg.Services.SessionService
  alias Tpg.Services.NotificationService
  alias Tpg.Dominio.Receptores
  alias Tpg.Handlers.NotificationHandler

  def init(req, _state) do
    # Extraer parámetros de la query string
    qs = :cowboy_req.parse_qs(req)
    usuario = :proplists.get_value("usuario", qs)
    contrasenia = :proplists.get_value("contrasenia", qs)
    operacion = :proplists.get_value("operacion", qs)

    {:cowboy_websocket, req,
    %Tpg.Dominio.Dto.WebSocket{usuario: usuario, contrasenia: contrasenia, operacion: operacion}}
  end

  def websocket_init(state) do
    usuario = state.usuario
    contrasenia = state.contrasenia
    operacion = String.to_atom(state.operacion)
    load_user(operacion, usuario, contrasenia, state)
  end

  defp load_user(operacion, nombre, contrasenia, state) do
    with {:ok, res} <- SessionService.loggear(operacion, %{nombre: nombre, contrasenia: contrasenia}),
      {:ok, _} <- SessionService.registrar_cliente( res.id, self()) do
        state = %{state | id: res.id}
        state = %{state | server_pid: res.pid}
        listar_contactos(state)
        NotificationService.listar_notificaciones(state)
        Logger.info("[WS] cliente registrado con la sesion #{inspect(self())}")
        NotificationHandler.notificar(:bienvenida, nombre, state)
      else
        {:error, {:already_started, pid}} ->
          {_tipo, frame, new_state} = NotificationHandler.notificar(:error, "Usuario #{nombre} ya está conectado", state)
          send(self(), :cerrar_conexion)
          {:reply, frame, new_state}

        {:error, reason} ->
          {_tipo, frame, new_state} = NotificationHandler.notificar(:error, "Error al conectar: #{inspect(reason)}", state)
          send(self(), :cerrar_conexion)
          {:reply, frame, new_state}
        end
  end
  def websocket_info(:cerrar_conexion, state) do
    Logger.info("[WS] Cerrando conexión por error de autenticación")
    {:stop, state}
  end
  # Manejar mensajes entrantes del cliente
  def websocket_handle({:text, json}, state) do
    case Jason.decode(json) do
      {:ok, %{"accion" => "agregar_contacto", "nombre_usuario" => nombre}} ->
        manejar_agregar_usuario(state, nombre)

      {:ok, %{"accion" => "abrir_chat", "tipo" => tipo, "receptor_id" => id}} ->
        manejar_abrir_chat(tipo, id, state)

      {:ok, %{"accion" => "enviar", "tipo" => tipo, "para" => destinatario, "mensaje" => mensaje}} ->
        manejar_envio(tipo, destinatario, mensaje, state)

      {:ok, %{"accion" => "leer_historial"}} ->
        manejar_lectura_historial(state)

      {:ok, %{"accion" => "listar_usuarios"}} ->
        manejar_listar_usuarios(state)

      {:ok, %{"accion" => "listar_usuarios_db"}} ->
        manejar_listar_usuarios_db(state)

      {:ok, %{"accion" => "crear_grupo", "miembros" => miembros, "nombre" => nombre_grupo}} ->
        manejar_creacion_grupo(nombre_grupo, miembros, state)

      {:ok, payload} ->
        respuesta =
          Jason.encode!(%{
            tipo: "error",
            mensaje: "Acción desconocida: #{inspect(payload)}"
          })

        {:reply, {:text, respuesta}, state}

      {:error, _} ->
        respuesta =
          Jason.encode!(%{
            tipo: "error",
            mensaje: "JSON inválido"
          })

        {:reply, {:text, respuesta}, state}
    end
  end


  def websocket_handle(_frame, state) do
    {:ok, state}
  end

  defp listar_contactos(state) do
    send(self(), {:listar_conversaciones, state.id})
  end

  def websocket_info({:listar_conversaciones, user_id}, state) do
    Logger.info("[WS] Listando contactos para el usuario TUPLA #{state.id}")
    Logger.info("[WS] Listando contactos para el usuario STATE #{state.id}")

    conversaciones = ChatService.obtener_conversaciones(user_id)

    respuesta =
      Jason.encode!(%{
        tipo: "listar_conversaciones",
        conversaciones: conversaciones
      })

    {:reply, {:text, respuesta}, state}
  end

  def websocket_info({:nuevo_mensaje, mensaje}, state) do
    Logger.info("[ws] marcando mensaje como leido")
    {:ok, _} = NotificationService.marcar_leido(state.id, mensaje.mensaje_id)
    respuesta =
      Jason.encode!(%{
        tipo: "mensaje_nuevo",
        de: mensaje.usuario.receptor_id,
        mensaje: mensaje.mensaje.contenido,
      })
    Logger.info("[ws] enviando mensaje al cliente ya marcado como leido")
    {:reply, {:text, respuesta}, state}
  end

  def websocket_info({:notificar_mensaje_recibido, _mensaje}, state) do
    Logger.info(
      "[ws] Recibiendo mensaje desde la sesion... Agregando a Bandeja de notificaciones"
    )

    {:no_reply, state}
  end

  def websocket_info({:mostrar_notificaciones, mensajes, emisor_id, tipoChat}, state) do
    Logger.info("[WS] Se estan cargando notificaciones para el usuario #{state.id}:\n #{inspect(mensajes)}")
    respuesta = Jason.encode!(%{
      tipo: "notificaciones",
      emisor_id: emisor_id,
      tipo_chat: tipoChat,
      mensajes: mensajes
    })

    {:reply, {:text, respuesta}, state}
  end

  def websocket_info({:mensaje_leido, mensaje}, state) do
    Logger.info("[ws] Un mensaje de los enviados fué leido")
    IO.inspect(mensaje)
    {:ok, state}
  end

  def websocket_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    respuesta =
      Jason.encode!(%{
        tipo: "sistema",
        mensaje: "Servidor de usuario caído, reconectando..."
      })

    {:reply, {:text, respuesta}, state}
  end

  @doc """
  Cuando se recibe una notificación desde algun punto del sistema, se delega al handler la respuesta que se debe devolver
  """
  def websocket_info({:notificacion, tipo, notificacion}, state) do
    Logger.info("[ws] Recibiendo notificacion...")
    IO.inspect({tipo, notificacion})
    NotificationHandler.handle_notification(tipo, notificacion, state)
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end

  # Cleanup cuando se cierra la conexión
  def terminate(_reason, _req, state) do
    if state.server_pid do
      SessionService.desloggear(state.id)
    end

    :ok
  end

  defp manejar_agregar_usuario(state, nombre) do
    Logger.debug("[ws handeler] agendando #{nombre} en #{state.usuario}...")
    with {:ok, agendado} <- SessionService.agendar(state.id, nombre),
        {:ok, _} = NotificationService.notificar(:contacto_agregado, agendado.contacto.contacto_id, %{receptor_id: state.id, nombre: state.usuario}) do
          Logger.info("[ws handeler] #{nombre} agendado con #{state.usuario}")
          {_tipo, frame1, state1} = NotificationHandler.notificar(:sistema, "Usuario #{nombre} agendado correctamente", state)
          {_tipo, frame2, state2} = NotificationHandler.handle_notification(:contacto_nuevo, %{tipo: "privado", receptor_id: agendado.contacto.contacto_id, nombre: nombre}, state1)
          {:reply, [frame1, frame2], state2}
  else
      {:error, motivo} ->
        Logger.warning("[ws handeler] #{nombre} no pudo ser agendado")
        NotificationHandler.notificar(:error, motivo, state)
    end
  end

  def manejar_abrir_chat(tipo, id_receptor, state) do
    {return_call, mensajes} =
      case SessionService.oir_chat(tipo, state.id, id_receptor, self()) do
        {:ok, mensajes} ->
          {"chat_abierto", mensajes}

        {:ya_esta_escuchando, mensajes} ->
          {"do_nothing", mensajes}

        _ ->
          {"mostrar_error", "Error abriendo chat"}
      end

    respuesta =
      Jason.encode!(%{
        tipo: return_call,
        receptor_id: state.id,
        mensajes: mensajes
      })

    {:reply, {:text, respuesta}, state}
  end

  defp manejar_envio(tipo, destinatario, mensaje, state) do
    case ChatService.enviar(tipo, state.id, destinatario, mensaje) do
      {:error, motivo} ->
        NotificationHandler.notificar(:error, motivo, state)

      {:ok, _mensaje} ->
        NotificationHandler.notificar(:sistema, "Mensaje enviado correctamente", state)
    end
  end

  defp manejar_lectura_historial(state) do
    case state.server_pid do
      nil ->
        NotificationHandler.notificar(:error, "No hay sesión activa", state)
      pid ->
        mensajes = ChatService.leer_mensajes(pid)

        respuesta =
          Jason.encode!(%{
            tipo: "historial",
            mensajes: mensajes
          })

        {:reply, {:text, respuesta}, state}
    end
  end

  defp manejar_listar_usuarios(state) do
    usuarios = SessionService.obtener_usuarios_activos()

    respuesta =
      Jason.encode!(%{
        tipo: "usuarios_activos",
        usuarios: usuarios
      })

    {:reply, {:text, respuesta}, state}
  end

  defp manejar_listar_usuarios_db(state) do
    usuarios =
      Receptores.obtener_usuarios()
      |> Enum.filter(fn user -> user.receptor_id != state.id end)

    respuesta =
      Jason.encode!(%{
        tipo: "listar_usuarios_db",
        usuarios: usuarios
      })

    {:reply, {:text, respuesta}, state}
  end

  defp manejar_creacion_grupo(nombre_grupo, miembros, state) do
    with {:ok, grupo} = ChatService.crear_grupo(nombre_grupo, [state.id | miembros]),
      {:ok, _} = NotificationService.notificar(:grupo_creado, miembros, %{grupo: grupo, creador: %{nombre: state.usuario, id: state.id}}) do
        NotificationHandler.handle_notification(:contacto_nuevo, %{tipo: "grupo", receptor_id: grupo.receptor_id, nombre: grupo.nombre}, state)
      else
        {:error, motivo} ->
          NotificationHandler.notificar(:error, "No se creo ningun grupo. #{motivo}", state)
      end
  end

end
