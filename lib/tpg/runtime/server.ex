defmodule Tpg.Runtime.Server do
  use GenServer
  require Logger

  def start_link(usuario) do
    GenServer.start_link(__MODULE__, usuario, name: {:global, usuario})
  end

  def init(usuario) do
    {:ok, %{usuario: usuario, mensajes: [], websocket_pids: []}}
  end

  # Nuevo: Registrar un WebSocket para notificaciones
  def handle_call({:registrar_websocket, pid}, _from, state) do
    Process.monitor(pid)
    nuevos_ws = [pid | state.websocket_pids]
    Logger.info("Websocket PID=#{inspect(pid)} asociado a Usuario=#{state.usuario}")
    {:reply, :ok, %{state | websocket_pids: nuevos_ws}}
  end

  def handle_call(:ver_historial, _from, state) do
    mensajes_ordenados = Enum.reverse(state.mensajes)
    {:reply, mensajes_ordenados, state}
  end

  def handle_cast({:recibir, de, mensaje}, state) do
    nuevo_mensaje = %{
      de: de,
      mensaje: mensaje,
      timestamp: DateTime.utc_now()
    }

    nuevos_mensajes = [nuevo_mensaje | state.mensajes]

    # Notificar a todos los WebSockets conectados
    Enum.each(state.websocket_pids, fn ws_pid ->
      Logger.info("Notificando a WS PID=#{inspect(ws_pid)} asociado a Usuario=#{state.usuario}, el mensaje=#{mensaje}")
      send(ws_pid, {:nuevo_mensaje, de, mensaje, nuevo_mensaje.timestamp})
    end)

    {:noreply, %{state | mensajes: nuevos_mensajes}}
  end


  # Limpiar WebSockets caídos
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.info("WebSocket PID=#{inspect(pid)} desconectado de Usuario=#{state.usuario}")
    nuevos_ws = List.delete(state.websocket_pids, pid)
    {:noreply, %{state | websocket_pids: nuevos_ws}}
  end
end
