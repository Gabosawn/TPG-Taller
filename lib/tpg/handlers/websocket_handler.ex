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
     %{usuario: usuario, contrasenia: contrasenia, operacion: operacion, id: nil, server_pid: nil}}
  end

  def websocket_init(state) do
    usuario = state.usuario
    contrasenia = state.contrasenia
    operacion = String.to_atom(state.operacion)

    # Intentar loggear al usuario
    case SessionService.loggear(operacion, %{nombre: usuario, contrasenia: contrasenia}) do
      {:ok, res} ->
        SessionService.registrar_cliente(res.id, self())
        # Enviar mensaje de bienvenida
        mensaje_bienvenida =
          Jason.encode!(%{
            tipo: "sistema",
            mensaje: "Conectado como #{usuario}",
            timestamp: DateTime.utc_now()
          })

        state = %{state | server_pid: res.pid}

        {:reply, {:text, mensaje_bienvenida}, %{state | id: res.id}}

      {:error, {:already_started, pid}} ->
        # Usuario ya está logueado
        mensaje_error =
          Jason.encode!(%{
            tipo: "error",
            mensaje: "Usuario #{usuario} ya está conectado"
          })

        {:reply, {:text, mensaje_error}, %{state | server_pid: pid}}

      {:error, reason} ->
        mensaje_error =
          Jason.encode!(%{
            tipo: "error",
            mensaje: "Error al conectar: #{inspect(reason)}"
          })

        {:reply, {:text, mensaje_error}, state}
    end
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

      {:ok, %{"accion" => "listar_conversaciones"}} ->
        manejar_listar_conversaciones(state)

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

  # Manejar mensajes internos de Elixir (notificaciones push)
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
    with {:ok, res} <- SessionService.agendar(state.id, nombre),
        {:ok, _} = NotificationService.notificar(:contacto_agregado, res.contacto.contacto_id, %{receptor_id: state.id, nombre: state.usuario}) do
          Logger.info("[ws handeler] #{nombre} agendado con #{state.usuario}")
          respuesta =
            Jason.encode!(%{
              tipo: "confirmacion",
              mensaje: "Usuario #{nombre} agendado correctamente"
            })
          {:reply, {:text, respuesta}, state}
  else
      {:error, motivo} ->
        Logger.warning("[ws handeler] #{nombre} no pudo ser agendado")
        respuesta =
          Jason.encode!(%{
            tipo: "error",
            mensaje: "#{motivo}"
          })
        {:reply, {:text, respuesta}, state}
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
        respuesta =
          Jason.encode!(%{
            tipo: "error",
            mensaje: "#{motivo}"
          })

        {:reply, {:text, respuesta}, state}

      {:ok, _mensaje} ->
        respuesta =
          Jason.encode!(%{
            tipo: "confirmacion",
            mensaje: "Mensaje enviado}"
          })

        {:reply, {:text, respuesta}, state}
    end
  end

  defp manejar_lectura_historial(state) do
    case state.server_pid do
      nil ->
        respuesta =
          Jason.encode!(%{
            tipo: "error",
            mensaje: "No hay sesión activa"
          })

        {:reply, {:text, respuesta}, state}

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
    case ChatService.crear_grupo(nombre_grupo, [state.id | miembros]) do
      {:ok, resultado} ->
        respuesta =
          Jason.encode!(%{
            tipo: "grupo_creado",
            grupo: resultado.nombre
          })

        {:reply, {:text, respuesta}, state}

      {:error, motivo} ->
        respuesta =
          Jason.encode!(%{
            tipo: "error",
            mensaje: "No se creo ningun grupo. #{motivo}"
          })

        {:reply, {:text, respuesta}, state}
    end
  end

  defp manejar_listar_conversaciones(state) do
    conversaciones = ChatService.obtener_conversaciones(state.id)

    respuesta =
      Jason.encode!(%{
        tipo: "listar_conversaciones",
        conversaciones: conversaciones
      })

    {:reply, {:text, respuesta}, state}
  end
end
