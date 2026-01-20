defmodule Tpg.Services.Chat do
  defstruct messages: []

  def nuevo() do
    %__MODULE__{}
  end

  def agregar_mensaje(chat, de, contenido) do
    nuevo_msg = %{emisor: de, contenido: contenido, fecha: Time.utc_now()}
    %{chat | messages: [nuevo_msg | chat.messages]}
  end

  def obtener_historial(chat) do
    Enum.reverse(chat.messages)
  end
end
