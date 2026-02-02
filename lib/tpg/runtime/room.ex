defmodule Tpg.Runtime.Room do
  use GenServer
  require Logger
  alias Tpg.Services.NotificationService
  alias Tpg.Dominio.Mensajeria
  alias Tpg.Dominio.Receptores

  defstruct group_id: nil, mensajes: [], miembros: []

  # Client API

  def start_link(group_id) do
    GenServer.start_link(__MODULE__, group_id, name: via_tuple(group_id))
  end

  defp via_tuple(group_id) do
    {:via, Registry, {Tpg.RoomRegistry, group_id}}
  end

  def mostrar_mensajes(usuario_sesion, usuario_chat) do
    Logger.info("[ROOM] [MOSTRAR MENSAJES] Usuario sesión: #{inspect(usuario_sesion)}, Usuario chat: #{inspect(usuario_chat)}")
    GenServer.call(via_tuple(usuario_chat), {:mostrar_mensajes, usuario_sesion})
  end

  def agregar_mensaje(emisor, group_id, contenido) do
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
  def handle_call({:mostrar_mensajes, usuario_sesion}, _from, state) do
    state.mensajes
    |> Enum.filter(fn msg -> msg.estado == "ENTREGADO" && msg.emisor != usuario_sesion end)
    |> List.last()
    |> case do
      nil -> :ok
      msg -> Receptores.marcar_ultimo_mensaje_visto(msg, usuario_sesion, state.group_id)
    end
    {:reply, {state.mensajes, self()}, state}
  end

  @impl true
  def handle_call({:agregar_mensaje, emisor, contenido}, _from, state) do
    case Mensajeria.enviar_mensaje(state.group_id, emisor, contenido) do
      {:ok, mensaje} ->
        nuevo_msg = %{id: mensaje.id, emisor: emisor, nombre: mensaje.nombre_emisor, contenido: contenido, estado: mensaje.estado, fecha: mensaje.inserted_at}
        new_state = %{state | mensajes: [nuevo_msg | state.mensajes]}
        # Notificar a todos los oyentes
        GenServer.cast(self(), {:mensaje, nuevo_msg})
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

  # Private Functions

  defp cargar_mensajes(group_id) do
    mensajes = Mensajeria.get_mensajes(group_id)
    %__MODULE__{group_id: group_id, mensajes: mensajes}
  end

  defp cargar_miembros(state) do
    %{state | miembros: Receptores.obtener_miembros(state.group_id)}
  end

  def handle_cast({:mensaje, mensaje}, state) do
    Logger.info("[room] Notificando usuarios...")
    contexto = %{usuarios: state.miembros, mensaje: mensaje, chat_pid: self()}
    NotificationService.notificar(:mensaje, contexto)
    {:noreply, state}
  end
end
