defmodule Tpg do
  @doc "Punto de entrada único para la mensajería"

  def loggear(usuario), do: Tpg.Runtime.Server.start_link(usuario)

  def enviar(de, para, msg), do: GenServer.cast(para, {:recibir, de, msg})

  def leer_mensajes(usuario), do: GenServer.call(usuario, :ver_historial)

  def desloggear(usuario) do
    case :global.whereis_name(usuario) do
      :undefined ->
        {:error, "Usuario no encontrado"}
      pid ->
        :ok = GenServer.stop(pid)
        {:ok, pid}
    end
  end

  def obtener_usuarios_activos(), do: :global.registered_names()
end
