defmodule Tpg.WebSocketHandler do
  @behaviour :cowboy_websocket
  require Logger
  alias Tpg.Services.ChatService
  alias Tpg.Services.SessionService
  alias Tpg.Services.NotificationService
  alias Tpg.Dominio.Receptores
  alias Tpg.Dominio.Mensajeria
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
      {:ok, _} <- SessionService.registrar_cliente(res.id, self()) do
        state = %{state | id: res.id}
        state = %{state | server_pid: res.pid}
        listar_contactos(state)
        listar_notificaciones(state)
        NotificationService.notificar(:en_linea, %{receptor_id: res.id, nombre: nombre})
        Logger.info("[WS] cliente registrado con la sesion #{inspect(self())}")
        NotificationHandler.notificar(:bienvenida, nombre, state)
      else
        {:error, {:already_started, pid}} ->
          {_tipo, frame, new_state} = NotificationHandler.notificar(:error, "Usuario #{nombre} ya está conectado", state)
          send(self(), :cerrar_conexion)
          {:reply, frame, new_state}

        {:error, reason} ->
          {_tipo, frame, new_state} = NotificationHandler.notificar(:error, "Error al iniciar sesion: #{inspect(reason)}", state)
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
        Logger.debug("[WS HANDLER] agregando contacto #{nombre}...")
        manejar_agregar_usuario(state, nombre)

      {:ok, %{"accion" => "abrir_chat", "tipo" => tipo, "receptor_id" => id}} ->
        manejar_abrir_chat(tipo, id, state)

      {:ok, %{"accion" => "enviar", "tipo" => tipo, "para" => destinatario, "mensaje" => mensaje}} ->
        manejar_envio(tipo, destinatario, mensaje, state)

      {:ok, %{"accion" => "crear_grupo", "miembros" => miembros, "nombre" => nombre_grupo}} ->
        manejar_creacion_grupo(nombre_grupo, miembros, state)

      {:ok, %{"accion" => "buscar_mensajes","tipo" => tipo, "emisor" => emisor, "destinatario" => destinatario, "query_text" => query_text}} ->
        manejar_buscar_mensajes(tipo, emisor, destinatario, query_text, state)

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

  defp listar_notificaciones(state) do
    Logger.info("[ws] listando notificaciones al loggearse... ")
    send(self(), {:listar_notificaciones, state.id})
  end


  def websocket_info({:listar_notificaciones, user_id}, state) do
    notificaciones = NotificationService.listar_notificaciones(user_id)

    respuesta =
      Jason.encode!(%{
        tipo: "notificaciones",
        notificaciones: notificaciones
      })

    {:reply, {:text, respuesta}, state}
  end

  def websocket_info({:listar_conversaciones, user_id}, state) do
    Logger.info("[WS] Listando contactos para el usuario TUPLA #{state.id}")
    Logger.info("[WS] Listando contactos para el usuario STATE #{state.id}")

    conversaciones = ChatService.obtener_conversaciones(user_id)

    respuesta =
      Jason.encode!(%{
        tipo: "contactos",
        conversaciones: conversaciones
      })

    {:reply, {:text, respuesta}, state}
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
    Logger.info("[ws] usuario #{state.usuario} Recibiendo notificacion...")
    NotificationHandler.handle_notification(tipo, notificacion, state)
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end

  # Cleanup cuando se cierra la conexión
  def terminate(_reason, _req, state) do
    if state.server_pid do
      NotificationService.notificar(:saliendo_de_linea, %{receptor_id: state.id, nombre: state.usuario})
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

  defp manejar_buscar_mensajes(tipo_de_chat, emisor_id, receptor_id, query_text, state) do
    case ChatService.buscar_mensajes(tipo_de_chat, emisor_id, receptor_id, query_text) do
      {:ok, mensajes} ->
        NotificationHandler.handle_notification(:mensajes_buscados, mensajes, state)
      {:error, motivo} ->
        NotificationHandler.notificar(:error, "Error buscando mensajes: #{motivo}", state)
    end
  end

  def manejar_abrir_chat(tipo, id_receptor, state) do

    with {:ok, mensajes} <- SessionService.oir_chat(tipo, state.id, id_receptor, self()),
        {:ok, receptor} <- Receptores.obtener(tipo, id_receptor),
        {:ok, receptor} <- SessionService.agregar_ultima_conexion(receptor) do
          NotificationHandler.handle_notification(:chat_abierto,
          %{
            receptor: receptor,
            mensajes: mensajes,
            tipo_de_chat: tipo,
            },
             state)
    else
      {:ya_esta_escuchando, mensajes} ->
        {:ok, state}
      _ ->
        NotificationHandler.handle_notification(:error, "Error abriendo chat" , state)
    end
  end

  defp manejar_envio(tipo, destinatario, mensaje, state) do
    case ChatService.enviar(tipo, state.id, destinatario, mensaje) do
      {:error, motivo} ->
        NotificationHandler.notificar(:error, motivo, state)

      {:ok, _mensaje} ->
        NotificationHandler.notificar(:sistema, "Mensaje enviado correctamente", state)
    end
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
