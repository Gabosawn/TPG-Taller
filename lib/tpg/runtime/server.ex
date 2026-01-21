defmodule Tpg.Runtime.Server do
  use GenServer

  def start_link(usuario) do
    GenServer.start_link(__MODULE__, usuario, name: {:global, usuario})
  end

  def init(usuario) do
    {:ok, %{usuario: usuario, mensajes: []}}
  end

  def handle_cast({:recibir, de, mensaje}, state) do
    nuevo_mensaje = %{
      de: de,
      mensaje: mensaje,
      timestamp: DateTime.utc_now()
    }

    nuevos_mensajes = [nuevo_mensaje | state.mensajes]
    {:noreply, %{state | mensajes: nuevos_mensajes}}
  end

  def handle_call(:ver_historial, _from, state) do
    mensajes_ordenados = Enum.reverse(state.mensajes)
    {:reply, mensajes_ordenados, state}
  end
end
