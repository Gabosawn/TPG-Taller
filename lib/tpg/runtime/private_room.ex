defmodule Tpg.Runtime.PrivateRoom do
  use GenServer
  require Logger
  alias Tpg.Dominio.Mensajeria

  defstruct listeners: [], usuarios: [], mensajes: []

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

  def agregar_mensaje(usuario_1, usuario_2, de, contenido) do
    room_id = normalize_room_id(usuario_1, usuario_2)
    GenServer.call(via_tuple(room_id), {:agregar_mensaje, de, contenido})
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
    new_state = %{state | listeners: [websocket_pid | state.listeners]}
    {:reply, {state.mensajes, self()}, new_state}
  end

  @impl true
  def handle_call({:quitar_oyente, websocket_pid}, _from, state) do
    new_listeners = Enum.reject(state.listeners, fn pid -> pid == websocket_pid end)

    new_state = %{state | listeners: new_listeners}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:agregar_mensaje, de, contenido}, _from, state) do
    nuevo_msg = %{emisor: de, contenido: contenido, estado: "ENVIADO", fecha: DateTime.utc_now()}

    para = Enum.find(state.usuarios, fn usuario -> usuario != de end)

    case Mensajeria.enviar_mensaje(para, de, nuevo_msg) do
      {:ok, _mensaje} ->
        Logger.info("[ROOM-PRIVATE] Mensaje guardado: #{nuevo_msg.contenido}, de #{de}")
        new_state = %{state | mensajes: [nuevo_msg | state.mensajes]}
        # Notificar a todos los oyentes
        notificar_oyentes(new_state.listeners, nuevo_msg)
        {:reply, {:ok, nuevo_msg}, new_state}

      {:error, motivo} ->
        Logger.alert(
          "[ROOM-PRIVATE] Mensaje perdido: #{nuevo_msg.contenido}, de #{de}. Motivo: #{inspect(motivo)}"
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
    new_state = %{state | listeners: List.delete(state.listeners, pid)}
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

  defp notificar_oyentes(listeners, mensaje) do
    Logger.info("[ROOM-PRIVATE] Notificando usuario_1, usuario_2...")

    Enum.each(listeners, fn pid ->
      Logger.info("[ROOM-PRIVATE] Notificando usuario")
      send(pid, {:nuevo_mensaje, mensaje})
    end)
  end
end
