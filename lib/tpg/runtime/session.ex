defmodule Tpg.Runtime.Session do
  use GenServer
  require Logger
  alias Tpg.Services.ChatService

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
        ChatService.quitar_oyente(state.chat_pid, ws_pid)
        Logger.info("[session] oyente quitado #{inspect(state.chat_pid)}")
      end
    end

    state = %{state | chat_pid: chat_pid}
    Logger.info("[session] Chat abierto #{inspect(state.chat_pid)}")
    {:reply, :ok, state}
  end

  def handle_call({:esta_escuchando_canal, chat_solicitado}, _from, state) do
    {:reply, state.chat_pid == chat_solicitado, state}
  end

  def handle_cast({:mensaje_leido, mensaje_id}, state) do
    nuevo_mensaje = %{
      mensaje: mensaje_id,
      timestamp: DateTime.utc_now()
    }
    Enum.each(state.websocket_pids, fn ws_pid ->
      Logger.info("Notificando a WS PID=#{inspect(ws_pid)} asociado a Usuario=#{state.usuario}, el mensaje=#{nuevo_mensaje.mensaje}")
      send(ws_pid, {:mensaje_leido, nuevo_mensaje})
    end)

    {:noreply, state}
  end

  # Limpiar WebSockets caídos
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.info("WebSocket PID=#{inspect(pid)} desconectado de Usuario=#{state.usuario}")
    nuevos_ws = List.delete(state.websocket_pids, pid)

    if state.chat_pid do
      ChatService.quitar_oyente(state.chat_pid, pid)
    end

    {:noreply, %{state | websocket_pids: nuevos_ws}}
  end

  defp agregar_oyente(state, websocket_pid) do
    # actualmente solo se puede relacionar un websocket con una sola sesion
    %{state | websocket_pids: [websocket_pid]}
  end

  @spec handle_call({:notificar, tipo :: atom(), mensaje::Map}, any, state :: map()) :: {:noreply, map()}
  def handle_call({:notificar, tipo, mensaje}, _, state) do
    Logger.info("[session] recibiendo llamado de notificacion...")
    ws_pid = List.first(state.websocket_pids)

    if ws_pid && Process.alive?(ws_pid) do
      send(ws_pid, {:notificacion, tipo, mensaje})
      {:reply, {:ok, "[session] notificacion enviada"}, state}
    else
      {:reply, {:error, "[session] WebSocket no disponible"}, state}
    end
  end
end
