defmodule Tpg do
  @doc "Punto de entrada único para la mensajería"

  def loggear(usuario) do
    case DynamicSupervisor.start_child(
      Tpg.DynamicSupervisor,
      {Tpg.Runtime.Server, usuario}
    ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:error, {:already_started, pid}}
    end
  end

  def enviar(de, para, msg), do: GenServer.cast(para, {:recibir, de, msg})

  def leer_mensajes(usuario), do: GenServer.call(usuario, :ver_historial)

  def desloggear(usuario) do
    case :global.whereis_name(usuario) do
      :undefined -> {:error, :not_found}
      pid ->
        DynamicSupervisor.terminate_child(Tpg.DynamicSupervisor, pid)
        {:ok, pid}
    end
  end

  def obtener_usuarios_activos(), do: :global.registered_names()
end
