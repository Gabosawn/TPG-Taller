defmodule Tpg.WebSocketHandler do
  @behaviour :cowboy_websocket
  require Logger

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
    case Tpg.loggear(operacion, %{nombre: usuario, contrasenia: contrasenia}) do
      {:ok, res} ->
        # Suscribirse a este proceso para recibir notificaciones
        Tpg.registrar_sesion(res.pid)
        # Enviar mensaje de bienvenida
        mensaje_bienvenida = Jason.encode!(%{
          tipo: "sistema",
          mensaje: "Conectado como #{usuario}",
          timestamp: DateTime.utc_now()
        })

        state = %{state | server_pid: res.pid}

        {:reply, {:text, mensaje_bienvenida}, %{state | id: res.id}}

      {:error, {:already_started, _pid}} ->
        # Usuario ya está logueado
        mensaje_error = Jason.encode!(%{
          tipo: "error",
          mensaje: "Usuario #{usuario} ya está conectado"
        })
        {:reply, {:text, mensaje_error}, state}

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

    IO.inspect(state, label: "Terminando conexión para el usuario")
    if state.server_pid do
      Tpg.desloggear(state.id)
    end
    :ok
  end

  # Funciones auxiliares privadas
  defp manejar_envio(destinatario, mensaje, state) do
    case :global.whereis_name(destinatario) do
      :undefined ->
        respuesta = Jason.encode!(%{
          tipo: "error",
          mensaje: "Usuario #{destinatario} no encontrado"
        })
        {:reply, {:text, respuesta}, state}

      pid ->
        Tpg.enviar(state.id, pid, mensaje)
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
        mensajes = Tpg.leer_mensajes(pid)
        respuesta = Jason.encode!(%{
          tipo: "historial",
          mensajes: mensajes
        })
        {:reply, {:text, respuesta}, state}
    end
  end

  defp manejar_listar_usuarios(state) do
    usuarios = Tpg.obtener_usuarios_activos()
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
