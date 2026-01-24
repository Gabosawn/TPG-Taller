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

  def crear_grupo(nombre_grupo, miembros) do
    with {:ok, miembros_validados} <- validate_miembros(miembros),
         {:ok, grupo} <- Tpg.Receptores.Cuentas.crear_grupo(%{nombre: nombre_grupo, }, miembros_validados) do
      {:ok, grupo}
    else
      {:error, message} -> {:error, message}
    end
  end
  def validate_miembros(miembros) do
    unique_miembros = Enum.uniq(miembros)
    users_exist = Enum.all?(unique_miembros, fn usuario -> Tpg.Receptores.Usuario.existe?(usuario) end)

    if users_exist do
      {:ok, unique_miembros}
    else
      {:error, "Algunos miembros no existen"}
    end
  end

end
