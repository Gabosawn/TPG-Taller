defmodule Tpg.Runtime.Room do
  use GenServer
  require Logger
  alias Tpg.Services.NotificationService
  alias Tpg.Dominio.Mensajeria
  alias Tpg.Dominio.Receptores

  defstruct listeners: %{}, group_id: nil, mensajes: [], miembros: []

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

  def quitar_oyente(group_id, websocket_pid) do
    GenServer.call(via_tuple(group_id), {:quitar_oyente, websocket_pid})
  end

  def agregar_mensaje(group_id, emisor, contenido) do
    GenServer.call(via_tuple(group_id), {:agregar_mensaje, emisor, contenido})
  end

  def obtener_historial(group_id) do
    GenServer.call(via_tuple(group_id), :obtener_historial)
  end

  # Server Callbacks

  @impl true
  def init(group_id) do
    room = cargar_mensajes(group_id)
    |> cargar_miembros()
    Logger.debug("[room] room inicializado: #{inspect(room)}")
    {:ok, room}
  end

  @impl true
  def handle_call({:agregar_oyente, websocket_pid}, _from, state) do
    {new_listeners, mensajes_respuesta} =
      if Map.has_key?(state.listeners, websocket_pid) do
        Logger.debug(
          "[room] Oyente #{inspect(websocket_pid)} ya existe en sala #{state.group_id}"
        )

        {state.listeners, state.mensajes}
      else
        Logger.debug(
          "[room] Oyente #{inspect(websocket_pid)} agregado a la sala #{state.group_id}"
        )

        monitor_ref = Process.monitor(websocket_pid)
        {Map.put(state.listeners, websocket_pid, monitor_ref), state.mensajes}
      end

    new_state = %{state | listeners: new_listeners}
    {:reply, {mensajes_respuesta, self()}, new_state}
  end

  @impl true
  def handle_call({:quitar_oyente, websocket_pid}, _from, state) do
    # Demonitorear y eliminar el oyente
    new_listeners =
      case Map.pop(state.listeners, websocket_pid) do
        {nil, listeners} ->
          Logger.debug(
            "[room] Oyente #{inspect(websocket_pid)} no estaba en sala #{state.group_id}"
          )

          listeners

        {monitor_ref, listeners} ->
          Process.demonitor(monitor_ref, [:flush])

          Logger.debug(
            "[room] Oyente #{inspect(websocket_pid)} eliminado de sala #{state.group_id}"
          )

          listeners
      end

    Logger.debug("[room] Cantidad oyentes: #{map_size(new_listeners)}, Sala: #{state.group_id}")
    new_state = %{state | listeners: new_listeners}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:agregar_mensaje, emisor, contenido}, _from, state) do
    case Mensajeria.enviar_mensaje(state.group_id, emisor, contenido) do
      {:ok, mensaje} ->
        nuevo_msg = %{id: mensaje.id, emisor: emisor, contenido: contenido, estado: mensaje.estado, fecha: mensaje.inserted_at}
        new_state = %{state | mensajes: [nuevo_msg | state.mensajes]}
        # Notificar a todos los oyentes
        notificar_oyentes(new_state.listeners, mensaje, emisor, nil)
        {:reply, {:ok, nuevo_msg}, new_state}

      {:error, motivo} ->
        Logger.alert(
          "[room] Mensaje perdido: #{contenido}, de #{emisor}. Motivo: #{inspect(motivo)}"
        )

        {:reply, {:error, motivo}, state}
    end
  end

  @impl true
  def handle_call(:obtener_historial, _from, state) do
    {:reply, Enum.reverse(state.mensajes), state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.debug("[room] Oyente #{inspect(pid)} desconectado de sala #{state.group_id}")
    new_listeners = Map.delete(state.listeners, pid)
    {:noreply, %{state | listeners: new_listeners}}
  end

  # Private Functions

  defp cargar_mensajes(group_id) do
    mensajes = Mensajeria.get_mensajes(group_id)
    %__MODULE__{group_id: group_id, mensajes: mensajes}
  end

  defp cargar_miembros(state) do
    %{state | miembros: Receptores.obtener_miembros(state.group_id)}
  end

  defp notificar_oyentes(listeners, mensaje, emisor, _all) do
    Logger.info("[room] Notificando usuarios...")
    Enum.each(Map.keys(listeners), fn pid ->
      Logger.info("[room] Notificando usuario")
      NotificationService.notificar_oyentes_de_mensaje(pid, mensaje, emisor, nil)
    end)
    # Enum.each(Map.keys(listeners), fn pid ->W
    #   Logger.info("[room] Notificando usuario")
    #   NotificationService.notificar_mensaje(pid, mensaje)
    # end)
  end
end
