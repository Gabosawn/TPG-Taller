defmodule Tpg.Services.NotificationService do

  @doc """
  Para notificar a un cliente que el chat que esta utilizando tiene un nuevo mensaje
  """
  @spec notificar_mensaje(pid :: pid, mensaje :: String.t()) :: {:ok, String.t()}
  def notificar_mensaje(ws_pid, mensaje) do
    send(ws_pid, {:nuevo_mensaje, mensaje})
  end

  @doc """
  Para notificar a un cliente en linea que una de sus conversaciones tiene un mensaje
  """
  @spec notificar_mensaje(pid :: pid, mensaje :: String.t()) :: {:ok, String.t()}
  def notificar_mensaje_en_bandeja(ws_pid, mensaje) do
    send(ws_pid, {:notificar_mensaje_recibido, mensaje})
  end
end
