defmodule Tpg.Runtime.PrivateRoom do
  use GenServer
  require Logger
  alias Tpg.Dominio.Mensajeria
  alias Tpg.Services.NotificationService

  defstruct listeners: %{}, usuarios: [], mensajes: []

  # Client API
  defp normalize_room_id(usuario_1, usuario_2) when usuario_1 < usuario_2 do
    {usuario_1, usuario_2}
  end

  defp normalize_room_id(usuario_1, usuario_2) do
    {usuario_2, usuario_1}
  end

  def start_link({usuario_1, usuario_2}) do
    room_id = normalize_room_id(usuario_1, usuario_2)
    GenServer.start_link(__MODULE__, Tuple.to_list(room_id), name: via_tuple(room_id))
  end

  defp via_tuple(room_id) do
    {:via, Registry, {Tpg.RoomRegistry, room_id}}
  end

  def agregar_oyente(usuario_1, usuario_2, websocket_pid) do
    room_id = normalize_room_id(usuario_1, usuario_2)
    GenServer.call(via_tuple(room_id), {:agregar_oyente, websocket_pid})
  end

  def quitar_oyente(usuario_1, usuario_2, websocket_pid) do
    room_id = normalize_room_id(usuario_1, usuario_2)
    GenServer.call(via_tuple(room_id), {:quitar_oyente, websocket_pid})
  end

  def agregar_mensaje(emisor, destinatario, contenido) do
    room_id = normalize_room_id(emisor, destinatario)
    GenServer.call(via_tuple(room_id), {:agregar_mensaje, emisor, destinatario, contenido})
  end

  def obtener_historial(usuario_1, usuario_2) do
    room_id = normalize_room_id(usuario_1, usuario_2)
    GenServer.call(via_tuple(room_id), :obtener_historial)
  end

  # Server Callbacks

  @impl true
  def init(usuarios) do
    Logger.warning("[PROC-CHAT-PRIVADO] Usuarios: #{inspect(usuarios)}")
    room = cargar_mensajes(usuarios)
    Logger.debug("[ROOM-PRIVATE] room inicializado: #{inspect(room)}")
    {:ok, room}
  end

  @impl true
  def handle_call({:agregar_oyente, websocket_pid}, _from, state) do
    {new_listeners, mensajes_respuesta} =
      if Map.has_key?(state.listeners, websocket_pid) do
        {state.listeners, state.mensajes}
      else
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
          listeners
        {monitor_ref, listeners} ->
          Process.demonitor(monitor_ref, [:flush])
          listeners
      end
    new_state = %{state | listeners: new_listeners}
    {:reply, :ok, new_state}
  end

  @impl true

  def handle_call({:agregar_mensaje, emisor, destinatario, contenido}, _from, state) do
    receptor = Enum.find(state.usuarios, fn usuario -> usuario != emisor end)

    case Mensajeria.enviar_mensaje(receptor, emisor, contenido) do
      {:ok, mensaje} ->
        nuevo_msg = %{id: mensaje.id, emisor: emisor, contenido: contenido, estado: mensaje.estado, fecha: mensaje.inserted_at}
        Logger.info("[ROOM-PRIVATE] Mensaje guardado: #{contenido}, de #{emisor}")
        new_state = %{state | mensajes: [nuevo_msg | state.mensajes]}
        # Notificar a todos los oyentes
        notificar_oyentes(new_state.listeners, mensaje, emisor, destinatario)
        {:reply, {:ok, nuevo_msg}, new_state}

      {:error, motivo} ->
        Logger.alert(
          "[ROOM-PRIVATE] Mensaje perdido: #{contenido}, de #{emisor}. Motivo: #{inspect(motivo)}"
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
    Logger.debug("[ROOM-PRIVATE] Oyente desconectado: #{inspect(pid)}")
    new_state = %{state | listeners: Map.delete(state.listeners, pid)}
    {:noreply, new_state}
  end

  # Private Functions

  defp cargar_mensajes(usuarios) do
    usuario_1 = Enum.at(usuarios, 0)
    usuario_2 = Enum.at(usuarios, 1)
    mensajes = Mensajeria.obtener_mensajes_usuarios(usuario_1, usuario_2)

    Logger.warning(
      "[ROOM-#{inspect({usuario_1, usuario_2})}] Mensajes cargados: #{inspect(mensajes)}"
    )

    %__MODULE__{usuarios: usuarios, mensajes: mensajes}
  end

  def notificar_oyentes(listeners, mensaje, emisor, destinatario) do
    Enum.each(Map.keys(listeners), fn pid ->
      Logger.info("[ROOM-PRIVATE] Notificando usuario")
      NotificationService.notificar_oyentes_de_mensaje(pid, mensaje, emisor, destinatario)
    end)
  end
end
