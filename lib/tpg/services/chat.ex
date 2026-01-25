defmodule Tpg.Services.ChatService do
  require Logger

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
  def obtener_conversaciones(id_usuario) do
    Tpg.Receptores.Agendado.obtener_contactos_agenda(id_usuario)
    ++ Tpg.Receptores.UsuariosGrupo.get_grupo_ids_by_usuario(id_usuario)
  end
  def agregar_oyente(tipo, user_id, reciever_id, ws_pid) do
    case tipo do
      "grupo" ->
        Logger.info("[session service] oyente para grupo #{reciever_id}")
        Tpg.Runtime.Room.agregar_oyente(reciever_id, ws_pid)
      "privado" ->
        Logger.info("[session service] oyente para chat privado #{inspect(reciever_id)}")
        Tpg.Runtime.PrivateRoom.agregar_oyente(user_id, reciever_id, ws_pid)
    end
  end
  def quitar_oyente(tipo, user_id, reciever_id, ws_pid) do
    case tipo do
      "grupo" ->
        Logger.info("[session service] oyente para grupo #{reciever_id}")
        Tpg.Runtime.Room.quitar_oyente(reciever_id, ws_pid)
      "privado" ->
        Logger.info("[session service] oyente para chat privado #{inspect(reciever_id)}")
        Tpg.Runtime.PrivateRoom.quitar_oyente(user_id, reciever_id, ws_pid)
    end
  end
end
