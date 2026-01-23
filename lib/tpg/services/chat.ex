defmodule Tpg.Services.Chat do
  defstruct messages: []
  require Logger

  def nuevo() do
    %__MODULE__{}
  end

  def agregar_mensaje(chat, de, contenido) do
    nuevo_msg = %{emisor: de, contenido: contenido, estado: "ENVIADO", fecha: Time.utc_now()}
    Logger.info("Guardando mensaje...: #{nuevo_msg.contenido}, de #{de}")
    case Tpg.Mensajes.MultiInsert.enviar_mensaje( chat.usuario, de, nuevo_msg ) do
      {:ok, mensaje} ->
        Logger.info("Mensaje guardado: #{nuevo_msg.contenido}, de #{de}")
        {:ok, %{chat | mensajes: [nuevo_msg | chat.mensajes]}}
      {:error, motivo} ->
        Logger.alert("Mensaje perdido: #{nuevo_msg.contenido}, de #{de}. Motivo: #{inspect(motivo)}")
        {:error, motivo}
    end
  end

  def obtener_historial(chat) do
    Enum.reverse(chat.mensajes)
  end
end
