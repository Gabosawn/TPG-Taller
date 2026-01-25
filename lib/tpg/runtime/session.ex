defmodule Tpg.Runtime.Session do
  use GenServer
  require Logger

  def start_link(usuario) do
    GenServer.start_link(__MODULE__, usuario, name: {:global, usuario})
  end

  def init(usuario) do
    {:ok, %{usuario: usuario, chat: nil, websocket_pids: []}}
  end

  def handle_call({:registrar_websocket, pid}, _from, state) do
    agregar_oyente(state, pid)
    Logger.info("[session] Websocket PID=#{inspect(pid)} asociado a Usuario=#{state.usuario}")
    {:reply, :ok, state}
  end

  def handle_call({:abrir_chat, group_pid}, _from, state) do
    Logger.info("[session] abriendo chat.. ")
    state = %{state | chat: group_pid}
    {:reply, :ok, state}
  end

  def handle_call(:ver_historial, _from, state) do
    mensajes_ordenados = Chat.obtener_historial(state)
    {:reply, mensajes_ordenados, state}
  end

  def handle_cast({:recibir, de, mensaje}, state) do
    nuevo_mensaje = %{
      de: de,
      mensaje: mensaje,
      timestamp: DateTime.utc_now()
    }
    Enum.each(state.websocket_pids, fn ws_pid ->
      Logger.info("Notificando a WS PID=#{inspect(ws_pid)} asociado a Usuario=#{state.usuario}, el mensaje=#{mensaje}")
      send(ws_pid, {:nuevo_mensaje_recibido, de, mensaje, nuevo_mensaje.timestamp})
    end)
    {:noreply, state}
  end


  # Limpiar WebSockets caídos
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.info("WebSocket PID=#{inspect(pid)} desconectado de Usuario=#{state.usuario}")
    nuevos_ws = List.delete(state.websocket_pids, pid)
    {:noreply, %{state | websocket_pids: nuevos_ws}}
  end

  defp agregar_oyente(state, websocket_pid) do
    %{state | websocket_pids: [websocket_pid]} # actualmente solo se puede relacionar un websocket con una sola sesion
  end
end
