defmodule Tpg.WebSocketHandler do
  @behaviour :cowboy_websocket
  require Logger
  alias Tpg.Services.ChatService
  alias Tpg.Services.SessionService

  def init(req, _state) do
    # Extraer parámetros de la query string
    qs = :cowboy_req.parse_qs(req)
    usuario = :proplists.get_value("usuario", qs)
    contrasenia = :proplists.get_value("contrasenia", qs)
    operacion = :proplists.get_value("operacion", qs)

    {:cowboy_websocket, req, %{usuario: usuario, contrasenia: contrasenia, operacion: operacion, id: nil, server_pid: nil}}
  end

  def websocket_init(state) do
    usuario = state.usuario
    contrasenia = state.contrasenia
    operacion = String.to_atom(state.operacion)

    # Intentar loggear al usuario
    case SessionService.loggear(operacion, %{nombre: usuario, contrasenia: contrasenia}) do
      {:ok, res} ->
        # Enviar mensaje de bienvenida
        mensaje_bienvenida = Jason.encode!(%{
          tipo: "sistema",
          mensaje: "Conectado como #{usuario}",
          timestamp: DateTime.utc_now()
        })
        {:reply, {:text, mensaje_bienvenida}, %{state | server_pid: res.pid} }

      {:error, {:already_started, pid}} ->
        # Usuario ya está logueado
        mensaje_error = Jason.encode!(%{
          tipo: "error",
          mensaje: "Usuario #{usuario} ya está conectado"
        })
        {:reply, {:text, mensaje_error}, %{state | server_pid: pid}}

      {:error, reason} ->
        mensaje_error = Jason.encode!(%{
          tipo: "error",
          mensaje: "Error al conectar: #{inspect(reason)}"
        })
        {:reply, {:text, mensaje_error}, state}
    end
  end

  # Manejar mensajes entrantes del cliente
  def websocket_handle({:text, json}, state) do
    case Jason.decode(json) do
      {:ok, %{"accion" => "abrir_chat", "receptor_id" => id}} ->
        manejar_abrir_chat(id, state)

      {:ok, %{"accion" => "enviar", "para" => destinatario, "mensaje" => mensaje}} ->
        manejar_envio(destinatario, mensaje, state)

      {:ok, %{"accion" => "leer_historial"}} ->
        manejar_lectura_historial(state)

      {:ok, %{"accion" => "listar_usuarios"}} ->
        manejar_listar_usuarios(state)

      {:ok, %{"accion" => "listar_usuarios_db"}} ->
        manejar_listar_usuarios_db(state)

      {:ok, payload} ->
        respuesta = Jason.encode!(%{
          tipo: "error",
          mensaje: "Acción desconocida: #{inspect(payload)}"
        })
        {:reply, {:text, respuesta}, state}

      {:error, _} ->
        respuesta = Jason.encode!(%{
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
  def websocket_info({:nuevo_mensaje, de, mensaje, timestamp}, state) do
    respuesta = Jason.encode!(%{
      tipo: "mensaje_nuevo",
      de: de,
      mensaje: mensaje,
      timestamp: timestamp
    })
    {:reply, {:text, respuesta}, state}
  end

  def websocket_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    respuesta = Jason.encode!(%{
      tipo: "sistema",
      mensaje: "Servidor de usuario caído, reconectando..."
    })
    {:reply, {:text, respuesta}, state}
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end

  # Cleanup cuando se cierra la conexión
  def terminate(_reason, _req, state) do
    if state.server_pid do
      SessionService.desloggear(state.usuario)
    end
    :ok
  end

  def manejar_abrir_chat(id_receptor, state) do
    # Suscribirse a este proceso para recibir notificaciones
    Tpg.oir_chat(id_receptor, state.server_pid)
  end

  defp manejar_envio(destinatario, mensaje, state) do
    case :global.whereis_name(destinatario) do
      :undefined ->
        respuesta = Jason.encode!(%{
          tipo: "error",
          mensaje: "Usuario #{destinatario} no encontrado"
        })
        {:reply, {:text, respuesta}, state}

      pid ->
        ChatService.enviar(state.id, pid, mensaje)
        respuesta = Jason.encode!(%{
          tipo: "confirmacion",
          mensaje: "Mensaje enviado a #{destinatario}"
        })
        {:reply, {:text, respuesta}, state}
    end
  end

  defp manejar_lectura_historial(state) do
    case state.server_pid do
      nil ->
        respuesta = Jason.encode!(%{
          tipo: "error",
          mensaje: "No hay sesión activa"
        })
        {:reply, {:text, respuesta}, state}

      pid ->
        mensajes = ChatService.leer_mensajes(pid)
        respuesta = Jason.encode!(%{
          tipo: "historial",
          mensajes: mensajes
        })
        {:reply, {:text, respuesta}, state}
    end
  end

  defp manejar_listar_usuarios(state) do
    usuarios = SessionService.obtener_usuarios_activos()
    respuesta = Jason.encode!(%{
      tipo: "usuarios_activos",
      usuarios: usuarios
    })
    {:reply, {:text, respuesta}, state}
  end

  defp manejar_listar_usuarios_db(state) do
    usuarios = Tpg.Receptores.Usuario.changeset(:listar, %{})
    respuesta = Jason.encode!(%{
      tipo: "usuarios",
      usuarios: usuarios
    })
    {:reply, {:text, respuesta}, state}
  end

end
