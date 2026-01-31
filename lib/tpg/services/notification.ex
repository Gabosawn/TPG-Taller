defmodule Tpg.Services.NotificationService do
  require Logger
  alias ElixirSense.Log
  alias Tpg.Repo
  alias Tpg.Dominio.Mensajes.{Recibido, Enviado, Mensaje}
  alias Tpg.Dominio.Receptores
  alias Tpg.Dominio.Receptores.Usuario
  alias Tpg.Services.SessionService
  import Ecto.Query
  @doc """
  Para notificar a un cliente que el chat que esta utilizando tiene un nuevo mensaje
  """
  @spec notificar_oyentes_de_mensaje(pid :: pid, mensaje :: %Mensaje{}) :: {:ok, String.t()} # | {:error, term()}
  def notificar_oyentes_de_mensaje(ws_pid, mensaje) do
    Logger.info("LLEGO HASTA AQUI---------1")
    IO.inspect(mensaje)

    tipo_de_chat =
      from(e in Enviado,
        join: r in Recibido,
        on: r.mensaje_id == e.mensaje_id,
        where: e.mensaje_id == ^mensaje.id,
        preload: [:usuario, :mensaje]
      )
      |> Repo.one()

    IO.inspect(tipo_de_chat)
    send(ws_pid, {:nuevo_mensaje, tipo_de_chat})
    send(ws_pid, {:notificar_mensaje_nuevo, tipo_de_chat})
  end

  @doc """
  Para notificar a un cliente en linea que una de sus conversaciones tiene un mensaje
  """
  @spec notificar_mensaje_en_bandeja(pid :: pid, mensaje :: String.t()) :: {:ok, String.t()} # | {:error, term()}
  def notificar_mensaje_en_bandeja(ws_pid, mensaje) do
    send(ws_pid, {:notificar_mensaje_recibido, mensaje})
  end


  @doc """
  Para marcar como leido un mensaje
  """
  @spec marcar_leido(user_id :: integer(), mensaje_id :: integer()) :: {:ok, String.t()}
  def marcar_leido(user_id, mensaje_id) do
    Logger.info("[notification] marcando como leido el mensaje #{mensaje_id} por el usuario #{user_id}")
    Tpg.Dominio.Mensajeria.actualizar_estado_mensaje("VISTO", mensaje_id)

    # |> case do
      # {1, _} ->
        # Notificar al emisor (opcional)
    notificar_emisor_lectura(mensaje_id, user_id)
    {:ok, "mensaje marcado como leido"}

      # {0, _} ->
        # {:error, :evento_no_encontrado}
    # end
  end

  @spec notificar_emisor_lectura(mensaje_id :: %Enviado{}, lector_id::integer()) :: term()
  defp notificar_emisor_lectura(mensaje_id, lector_id) do
    emisor_id = from(e in Enviado,
      where: e.mensaje_id == ^mensaje_id,
      select: e.usuario_id)
      |> Repo.one()
    case lector_id == emisor_id do
      true ->
        Logger.info("[notification] notificacion de lectura emitida por su enviador")
        {:ok, "[notificacion] mismo usuario no lee su propio mensaje"}
      false ->
        {:ok, emisor_pid} = SessionService.get_session_pid(emisor_id)
        GenServer.cast(emisor_pid, {:mensaje_leido, mensaje_id})
        Logger.info("[notification] notificacion de lectura enviada a su emisor")
    end
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
    mensaje = %{contacto: contexto}
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
    mensaje = %{contacto: contexto}
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
    Tpg.Dominio.Mensajeria.obtener_mensajes_estado_enviado(id_usuario)
    {:ok, "[notification service] estado mensajes enviados"}
  end
end
