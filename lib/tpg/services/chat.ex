defmodule Tpg.Services.ChatService do
  require Logger
  alias Tpg.Dominio.Receptores
  alias Tpg

  def enviar(tipo, de, para, msg) do
    Logger.debug("Enviando mensaje de #{inspect(de)} a #{inspect(para)}: #{msg}")

    case tipo do
      "grupo" ->
        Tpg.Runtime.Room.agregar_mensaje(para, de, msg)

      "privado" ->
        Tpg.Runtime.PrivateRoom.agregar_mensaje(de, para, de, msg)
    end

    {:ok, "mensaje enviado"}
  end

  def leer_mensajes(usuario) do
    Logger.debug("Leyendo mensajes de #{inspect(usuario)}")
    GenServer.call(usuario, :ver_historial)
  end

  def crear_grupo(nombre_grupo, miembros) do
    with {:ok, miembros_validados} <- validate_miembros(miembros),
         {:ok, grupo} <- Receptores.crear_grupo(%{nombre: nombre_grupo}, miembros_validados) do
      {:ok, _pid} = Tpg.habilitar_canales(Enum.at(miembros, 0))
      {:ok, grupo}
    else
      {:error, message} -> {:error, message}
    end
  end

  def validate_miembros(miembros) do
    unique_miembros = Enum.uniq(miembros)

    users_exist =
      Enum.all?(unique_miembros, fn usuario -> Receptores.existe_usuario?(usuario) end)

    if users_exist do
      {:ok, unique_miembros}
    else
      {:error, "Algunos miembros no existen"}
    end
  end

  def obtener_conversaciones(id_usuario) do
    Receptores.obtener_contactos_agenda(id_usuario) ++
      Receptores.get_grupo_ids_by_usuario(id_usuario)
  end

  def agregar_oyente(tipo, user_id, reciever_id, ws_pid) do
    case tipo do
      "grupo" ->
        Logger.info("[session service] oyente para grupo #{reciever_id}")
        Tuple.insert_at(Tpg.Runtime.Room.agregar_oyente(reciever_id, ws_pid), 0, :ok)

      "privado" ->
        Logger.info("[session service] oyente para chat privado #{inspect(reciever_id)}")

        Tuple.insert_at(
          Tpg.Runtime.PrivateRoom.agregar_oyente(user_id, reciever_id, ws_pid),
          0,
          :ok
        )
    end
  end

  def quitar_oyente(chat_pid, ws_pid) do
    GenServer.call(chat_pid, {:quitar_oyente, ws_pid})
  end
end
