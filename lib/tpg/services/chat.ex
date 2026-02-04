defmodule Tpg.Services.ChatService do
  require Logger
  alias Tpg.Dominio.{Receptores, Mensajeria}
  alias Tpg.Runtime.{Room, PrivateRoom}

  def enviar(tipo, emisor, destinatario, msg) do
    Logger.debug("Enviando mensaje de #{inspect(emisor)} a #{inspect(destinatario)}: #{msg}")

    case tipo do
      "grupo" ->
        Room.agregar_mensaje(emisor, destinatario, msg)

      "privado" ->
        PrivateRoom.agregar_mensaje(emisor, destinatario, msg)
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

  def mostrar_mensajes(tipo, usuario_id, receptor_id) do
    case tipo do
      "grupo" ->
        Tuple.insert_at(Room.mostrar_mensajes(usuario_id, receptor_id), 0, :ok)

      "privado" ->
        Tuple.insert_at(PrivateRoom.mostrar_mensajes(usuario_id, receptor_id), 0, :ok)
    end
  end

  def buscar_mensajes(tipo_de_chat, emisor_id, receptor_id, query_text) do
    case Mensajeria.buscar_mensajes(tipo_de_chat, emisor_id, receptor_id, query_text) do
      [] -> {:error, "No se encontraron mensajes que coincidan con la búsqueda."}
      mensajes -> {:ok, mensajes}
    end
  end

end
