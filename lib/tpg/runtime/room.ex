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

  def actualizar_estado_mensaje(estado, mensajes_ids, id_usuario, id_emisor) do
    GenServer.call(via_tuple(id_emisor), {:actualizar_estado_mensaje, estado, mensajes_ids})
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
  def handle_call({:actualizar_estado_mensaje, estado, mensajes_ids}, _from, state) do
    new_state = actualizar_estado_mensajes(state, estado, mensajes_ids)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:mostrar_mensajes, usuario_sesion}, _from, state) do
    state.mensajes
    |> Enum.max_by(& &1.id, fn -> nil end)
    |> case do
      nil -> :ok
      ultimo -> Receptores.marcar_mensaje_visto(ultimo, usuario_sesion, state.group_id)
    end

    mensajes = Enum.filter(state.mensajes, fn msg ->
      msg.emisor != usuario_sesion and msg.estado == "ENTREGADO"
    end)

    new_state = actualizar_estado_mensajes(state, "VISTO", Enum.map(mensajes, & &1.id))

    {:reply, {new_state.mensajes, self()}, new_state}
  end

  @impl true
  def handle_call({:agregar_mensaje, emisor, contenido}, _from, state) do
    case Mensajeria.enviar_mensaje(state.group_id, emisor, contenido) do
      {:ok, mensaje} ->
        Logger.info("[ROOM] Mensaje guardado: #{contenido}, de #{emisor} con estado #{mensaje.estado}")

        new_state = %{state | mensajes: [mensaje | state.mensajes]}
        GenServer.cast(self(), {:mensaje, mensaje, emisor, state.group_id})
        Receptores.marcar_mensaje_visto(mensaje, emisor, state.group_id)
        Receptores.marcar_mensaje_entregado(mensaje, emisor, state.group_id)
        {:reply, {:ok, mensaje}, new_state}

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

  def handle_cast({:mensaje, mensaje, emisor, group_id}, state) do
    Logger.info("[room] Notificando usuarios...")
    contexto = %{usuarios: state.miembros, mensaje: mensaje, chat_pid: self(), emisor: emisor, tipo: "grupo", receptor: group_id}
    NotificationService.notificar(:mensaje, contexto)
    {:noreply, state}
  end

  defp actualizar_estado_mensajes(state, estado, mensajes_ids) do
    IO.inspect(state.mensajes, label: "[ROOM] Mensaje antes de:")
    [vistos, recibido] = Tpg.Dominio.Receptores.buscar_mensaje_comun_usuarios(state.group_id)

    ids_set = MapSet.new(mensajes_ids)

    new_mensajes =
      case estado do
        "ENTREGADO" ->
          Enum.filter(state.mensajes, fn msg ->
            MapSet.member?(ids_set, msg.id) and msg.id <= recibido and msg.estado == "ENVIADO"
          end)
          |> Tpg.Dominio.Mensajeria.marcar_mensajes("ENTREGADO")

          Enum.map(state.mensajes, fn msg ->
            if MapSet.member?(ids_set, msg.id) and msg.id <= recibido do
              %{msg | estado: estado}
            else
              msg
            end
          end)

        "VISTO" ->
          Enum.filter(state.mensajes, fn msg ->
            MapSet.member?(ids_set, msg.id) and msg.id <= vistos and msg.estado == "ENTREGADO"
          end)
          |> Tpg.Dominio.Mensajeria.marcar_mensajes("VISTO")

          Enum.map(state.mensajes, fn msg ->
            if MapSet.member?(ids_set, msg.id) and msg.id <= vistos do
              %{msg | estado: estado}
            else
              msg
            end
          end)
      end

    IO.inspect(new_mensajes, label: "[ROOM] Mensaje despues de:")
    %{state | mensajes: new_mensajes}
  end
end
