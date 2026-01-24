defmodule Tpg.Runtime.Room do
  alias ElixirSense.Log
  use GenServer
  require Logger

  defstruct listeners: [], group_id: nil, mensajes: []

  # Client API

  def start_link(group_id) do
    GenServer.start_link(__MODULE__, group_id, name: via_tuple(group_id))
  end

  defp via_tuple(group_id) do
    {:via, Registry, {Tpg.RoomRegistry, group_id}}
  end

  def agregar_oyente(group_id, websocket_pid) do
    GenServer.call(via_tuple(group_id), {:agregar_oyente, websocket_pid})
  end

  def agregar_mensaje(group_id, de, contenido) do
    GenServer.call(via_tuple(group_id), {:agregar_mensaje, de, contenido})
  end

  def obtener_historial(group_id) do
    GenServer.call(via_tuple(group_id), :obtener_historial)
  end

  # Server Callbacks

  @impl true
  def init(group_id) do
    room = cargar_mensajes(group_id)
    Logger.debug("[room] room inicializado: #{inspect(room)}")
    {:ok, room}
  end

  @impl true
  def handle_call({:agregar_oyente, websocket_pid}, _from, state) do
    Process.monitor(websocket_pid)
    new_state = %{state | listeners: [websocket_pid | state.listeners]}
    {:reply, state.mensajes, new_state}
  end

  @impl true
  def handle_call({:agregar_mensaje, de, contenido}, _from, state) do
    nuevo_msg = %{emisor: de, contenido: contenido, estado: "ENVIADO", fecha: DateTime.utc_now()}
    Logger.info("Guardando mensaje...: #{nuevo_msg.contenido}, de #{de}")

    case Tpg.Mensajes.MultiInsert.enviar_mensaje(state.group_id, de, nuevo_msg) do
      {:ok, _mensaje} ->
        Logger.info("Mensaje guardado: #{nuevo_msg.contenido}, de #{de}")
        new_state = %{state | mensajes: [nuevo_msg | state.mensajes]}
        # Notificar a todos los oyentes
        notificar_oyentes(new_state.listeners, nuevo_msg)
        {:reply, {:ok, nuevo_msg}, new_state}

      {:error, motivo} ->
        Logger.alert("Mensaje perdido: #{nuevo_msg.contenido}, de #{de}. Motivo: #{inspect(motivo)}")
        {:reply, {:error, motivo}, state}
    end
  end

  @impl true
  def handle_call(:obtener_historial, _from, state) do
    {:reply, Enum.reverse(state.mensajes), state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.debug("[room] Oyente desconectado: #{inspect(pid)}")
    new_state = %{state | listeners: List.delete(state.listeners, pid)}
    {:noreply, new_state}
  end

  # Private Functions

  defp cargar_mensajes(group_id) do
    mensajes = Tpg.Mensajes.Recibido.get_mensajes(group_id)
    %__MODULE__{group_id: group_id, mensajes: mensajes}
  end

  defp notificar_oyentes(listeners, mensaje) do
    Enum.each(listeners, fn pid ->
      send(pid, {:nuevo_mensaje, mensaje})
    end)
  end
end
