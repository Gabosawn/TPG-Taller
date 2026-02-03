defmodule Tpg.Services.NotificationService do
  require Logger
  alias Tpg.Dominio.Receptores
  alias Tpg.Dominio.Mensajeria
  alias Tpg.Services.SessionService

  @doc """
  Notifica a un usuario o grupo de usuarios 'en_linea' sobre un nuevo mensaje
  """
  @spec notificar(:mensaje, contexto:: %{usuarios: [integer()], mensaje: %{}, chat_pid: pid(), emisor: integer(), tipo: String.t(), receptor: integer()}) :: nil
  def notificar(:mensaje, contexto) do
    Enum.each(contexto.usuarios, fn usuario ->
      if SessionService.en_linea?(usuario) do
        spawn(fn  ->
          notificar_mensaje(usuario, contexto)
        end)
      end
    end)
  end

  defp notificar_mensaje(id_usuario, contexto) do
    case SessionService.esta_escuchando?(id_usuario, contexto.chat_pid) do
      true -> notificar_mensaje_con_push(id_usuario, contexto.mensaje, contexto.emisor, contexto.receptor, contexto.tipo)
      false -> notificar_mensaje_en_bandeja(id_usuario, contexto.mensaje, contexto.emisor, contexto.receptor, contexto.tipo)
    end
  end

  # Para notificar a un cliente en linea que una de sus conversaciones tiene un mensaje
  @spec notificar_mensaje_en_bandeja(id_usuario ::integer(), mensaje::map(), emisor:: integer(), receptor:: integer(), tipo:: String.t()) :: nil
  defp notificar_mensaje_en_bandeja(id_usuario, mensaje, emisor, receptor, tipo) do
    SessionService.notificar_mensaje(id_usuario, :notificacion_bandeja, mensaje, emisor, receptor, tipo)
  end
  # Para notificar a un cliente que el chat que esta utilizando tiene un nuevo mensaje
  @spec notificar_mensaje_con_push(id_usuario:: integer(), mensaje:: map(), emisor:: integer(), receptor:: integer(), tipo:: String.t()) :: nil
  defp notificar_mensaje_con_push(id_usuario, mensaje, emisor, receptor, tipo) do
    SessionService.notificar_mensaje(id_usuario, :mensaje_nuevo, mensaje, emisor, receptor, tipo)
  end

  @doc """
  Para marcar como entregado un mensaje
  """
  @spec marcar_entregado(mensaje:: %{}, id_usuario :: integer()) :: {:ok, String.t()}
  def marcar_entregado(mensaje, id_usuario) do
    Logger.info("[notification] marcando como entregado el mensaje #{mensaje.id} por el usuario #{id_usuario}")
    if mensaje.emisor == id_usuario do
      {:pass, "No se puede marcar como entregado un mensaje desde el mismo emisor"}
    end
    Mensajeria.actualizar_estado_mensaje("ENTREGADO",mensaje.id)
  end

  @spec enviar_notificacion(usuario_id::integer(), mensaje:: atom(), notificacion:: map()) ::  {:ok, any()} | {:pass | :error, any()}
  defp enviar_notificacion(usuario_id, mensaje, notificacion) do
    with {:ok, session_pid} <- SessionService.get_session_pid(usuario_id),
      {:ok, mensaje} <- GenServer.call(session_pid, {:notificar, mensaje, notificacion}) do
        Logger.info("[notification service] notificacion enviada")
        {:ok, mensaje}
    else
      {:error, :undefined} ->
        {:pass, "Usuario fuera de linea"}
      {:error, mensaje} ->
        {:error, mensaje}
    end
  end
  @doc """
  Notifica a un usuario objetivo que fué agendado por otro usuario remitente como contacto
  contacto: Usuario emisor
  usuario_id: Usuario objetivo de la notificacion
  """
  @spec notificar( :contacto_agregado, usuario_id:: integer(), contacto:: %{}) :: {:ok, any()} | {:error, any()}
  def notificar(:contacto_agregado, usuario_id, contacto) do
    mensaje = %{contacto: contacto, por: usuario_id}
    case enviar_notificacion(usuario_id, :agregado_como_contacto, mensaje) do
      {:ok, mensaje} ->
        #if Receptores.son_contactos?(usuario_id, contacto.receptor_id) do
          enviar_notificacion_si_id_esta_en_linea(:contacto_en_linea, %{contacto: %{receptor_id: contacto.receptor_id, nombre: contacto.nombre}}, contacto.receptor_id, usuario_id)
          enviar_notificacion_si_id_esta_en_linea(:contacto_en_linea, %{contacto: %{receptor_id: usuario_id, nombre: ""}}, usuario_id, contacto.receptor_id)
        #end
        {:ok, mensaje}
      {:error, mensaje} ->
        {:error, mensaje}
      {:pass, mensaje} ->
        {:ok, mensaje}
    end
  end

  @doc """
  Notifica a un grupo de usuarios que fueron agregados a un grupo
  miembros: Lista de id's Usuarios objetivo de la notificacion
  usuario_id: Usuario objetivo de la notificacion
  """
  @spec notificar( :grupo_creado, miembros :: [integer()], contexto:: %{}) :: {:ok, any()} | {:error, String.t()}
  def notificar(:grupo_creado, miembros, contexto) do
    mensaje = %{grupo: contexto.grupo, creador: contexto.creador}
    Logger.info("[notification service] notificando creacion de grupo a sus miembros...")
    Enum.each(miembros, fn usuario_id ->
      enviar_notificacion(usuario_id, :grupo_creado, mensaje)
    end)
    {:ok, "[notification service] notificaciones distribuidas con exito"}
  end
  @doc """
  Notifica a un los contactos de un usuario que este esta en linea
  receptor_id: Id del usuario en linea
  nombre: Nombre del usuario en linea
  """
  @spec notificar(:en_linea, contexto :: %{receptor_id: integer(), nombre: String.t()}) :: {:ok, any()} | {:error, String.t()}
  def notificar(:en_linea, contexto) do
    with contactos <- Receptores.obtener_contactos_agenda(contexto.receptor_id) do
      Enum.each(contactos, fn contacto ->
        Logger.info("[notification service] enviando notificacion a #{contacto.id}")
        enviar_notificacion_si_id_esta_en_linea(:contacto_en_linea, %{contacto: %{receptor_id: contacto.id, nombre: ""}}, contacto.id, contexto.receptor_id)
        enviar_notificacion_si_id_esta_en_linea(:contacto_en_linea, %{contacto: %{receptor_id: contexto.receptor_id, nombre: contexto.nombre}}, contexto.receptor_id, contacto.id)
      end)
      {:ok, "[notification service] notificaciones distribuidas con exito"}
    else
      {:error, motivo} ->
        {:error, motivo}
    end
  end
  @spec enviar_notificacion_si_id_esta_en_linea( operacion:: atom(), mensaje:: %{}, id_a_validar:: integer(), id_objetivo:: integer()) :: {:ok, any()} | {:error, String.t()}
  defp enviar_notificacion_si_id_esta_en_linea(operacion, mensaje, id_a_validar, id_objetivo) do
    with {:ok, _} <-  SessionService.get_session_pid(id_a_validar) do
        enviar_notificacion(id_objetivo, operacion, mensaje)
        Logger.info("[notification service] id_validado y notificacion enviada")
        {:ok, "[notification service] usuario validado y notificacion enviada"}
    end
  end
  @doc """
  Notifica a un los contactos de un usuario que este saliendo de 'en_linea'
  receptor_id: Id del usuario en linea
  nombre: Nombre del usuario en linea
  """
  @spec notificar(:saliendo_de_linea, contexto :: %{receptor_id: integer(), nombre: String.t()}) :: {:ok, any()} | {:error, String.t()}
  def notificar(:saliendo_de_linea, contexto) do
    with contactos <- Receptores.obtener_contactos_agenda(contexto.receptor_id) do
      Enum.each(contactos, fn contacto ->
        enviar_notificacion_si_id_esta_en_linea(:saliendo_de_linea, %{contacto: %{receptor_id: contexto.receptor_id, nombre: contexto.nombre}}, contacto.id, contacto.id)
      end)
      {:ok, " [notification service] notificaciones distribuidas con exito"}
    else
      {:error, motivo} ->
        {:error, motivo}
    end
  end

  @spec listar_notificaciones(id_usuario::integer()) :: any()
  def listar_notificaciones(id_usuario) do
    Logger.info("[NOTIFICATION SERVICE] Listando notificaciones para el usuario #{id_usuario}...")

    usuarios = Tpg.Dominio.Mensajeria.mensajes_por_usuario(id_usuario)
    Logger.info("[NOTIFICATION SERVICE] Mensajes por usuario obtenidos: #{inspect(usuarios)}")

    Tpg.Dominio.Mensajeria.mensajes_por_grupo(id_usuario)
    |> Enum.concat(usuarios)
    |> Enum.sort_by(fn %{mensajes: mensajes} ->
      mensajes
      |> Enum.max_by(& &1.fecha, fn -> %{fecha: ~N[0000-01-01 00:00:00]} end)
      |> Map.get(:fecha)
    end, :desc)
  end
end
