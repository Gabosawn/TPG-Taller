defmodule Tpg.Services.ChatService do
  require Logger

  def agregar_oyente(chat, websocket_pid) do
    Process.monitor(websocket_pid)
    %{chat | listeners: [websocket_pid | chat.listeners]}
  end

  def enviar(de, para, msg) do
    Logger.debug("Enviando mensaje de #{inspect(de)} a #{inspect(para)}: #{msg}")
    GenServer.cast(para, {:recibir, de, msg})
  end

  def leer_mensajes(usuario) do
    Logger.debug("Leyendo mensajes de #{inspect(usuario)}")
    GenServer.call(usuario, :ver_historial)
  end

end
