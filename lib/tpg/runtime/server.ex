defmodule Tpg.Runtime.Server do
  use GenServer
  alias Tpg.Services.Chat

  # API Pública
  def start_link(nombre) do
    GenServer.start_link(__MODULE__, nil, name: nombre)
  end

  # Callbacks
  @impl true
  def init(_) do
    {:ok, Chat.nuevo()} # Inicializa el núcleo funcional
  end

  @impl true
  def handle_cast({:recibir, de, contenido}, chat_state) do
    nuevo_estado = Chat.agregar_mensaje(chat_state, de, contenido)
    {:noreply, nuevo_estado}
  end

  @impl true
  def handle_call(:ver_historial, _from, chat_state) do
    {:reply, Chat.obtener_historial(chat_state), chat_state}
  end
end
