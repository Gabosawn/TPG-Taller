defmodule Tpg do
  @doc "Punto de entrada único para la mensajería"

  def loggear(usuario), do: Tpg.Runtime.Server.start_link(usuario)

  def enviar(de, para, msg), do: GenServer.cast(para, {:recibir, de, msg})

  def leer_mensajes(usuario), do: GenServer.call(usuario, :ver_historial)
end
