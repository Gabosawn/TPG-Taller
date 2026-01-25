defmodule Tpg.Runtime.Session do
  use GenServer
  require Logger

  def start_link(usuario) do
    GenServer.start_link(__MODULE__, usuario, name: {:global, usuario})
  end

  def init(usuario) do
    {:ok, %{usuario: usuario, chat_pid: nil, websocket_pids: []}}
  end

  def handle_call({:registrar_websocket, pid}, _from, state) do
    Process.monitor(pid)
    nuevo_state = agregar_oyente(state, pid)
    Logger.info("[session] Websocket PID=#{inspect(pid)} asociado a Usuario=#{state.usuario}")
    {:reply, :ok, nuevo_state}
  end

  def handle_call({:abrir_chat, chat_pid}, _from, state) do
    Logger.info("[session] abriendo chat #{inspect(chat_pid)}")
    if state.chat_pid do
      Logger.info("[session] quitando oyente #{inspect(state.chat_pid)}")
      ws_pid = Enum.at(state.websocket_pids, 0)
      if ws_pid && Process.alive?(ws_pid) do
        Tpg.Services.ChatService.quitar_oyente(state.chat_pid, ws_pid)
        Logger.info("[session] oyente quitado #{inspect(state.chat_pid)}")
      end
    end
    state = %{state | chat_pid: chat_pid}
    Logger.info("[session] Chat abierto #{inspect(state.chat_pid)}")
    {:reply, :ok, state}
  end

  def handle_call(:ver_historial, _from, state) do
    mensajes_ordenados = Chat.obtener_historial(state)
    {:reply, mensajes_ordenados, state}
  end
  def handle_call({:esta_escuchando_canal, chat_solicitado}, _from, state) do
    {:reply, state.chat_pid == chat_solicitado, state}
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
    if state.chat_pid do
      Tpg.Services.ChatService.quitar_oyente(state.chat_pid, pid)
    end
    {:noreply, %{state | websocket_pids: nuevos_ws}}
  end

  defp agregar_oyente(state, websocket_pid) do
    %{state | websocket_pids: [websocket_pid]} # actualmente solo se puede relacionar un websocket con una sola sesion
  end
end
