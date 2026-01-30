defmodule Tpg.Services.NotificationService do
  require Logger
  alias Tpg.Repo
  alias Tpg.Dominio.Mensajes.{Recibido, Enviado, Mensaje}
  alias Tpg.Dominio.Receptores.Usuario
  alias Tpg.Services.SessionService
  import Ecto.Query
  @doc """
  Para notificar a un cliente que el chat que esta utilizando tiene un nuevo mensaje
  """
  @spec notificar_mensaje(pid :: pid, mensaje :: %Mensaje{}) :: {:ok, String.t()} # | {:error, term()}
  def notificar_mensaje(ws_pid, mensaje) do
    mensaje =
    from(e in Enviado,
      where: e.mensaje_id == ^mensaje.id,
      preload: [:usuario, :mensaje]
    )
    |> Repo.one()
    send(ws_pid, {:nuevo_mensaje, mensaje})
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
    hora = DateTime.utc_now() |> DateTime.truncate(:second)

    from(e in Recibido,
      where: e.mensaje_id == ^mensaje_id and e.receptor_id == ^user_id
    )
    |> Repo.update_all(set: [
      leido_at: hora,
    ])
    # |> case do
      # {1, _} ->
        # Notificar al emisor (opcional)
    notificar_emisor_lectura(mensaje_id, user_id, hora)
    {:ok, hora}

      # {0, _} ->
        # {:error, :evento_no_encontrado}
    # end
  end

  @spec notificar_emisor_lectura(mensaje_id :: %Enviado{}, lector_id::integer(), time::DateTime) :: term()
  defp notificar_emisor_lectura(mensaje_id, lector_id, hora) do
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

  @doc """
  Envia a un id una notificacion con un mensaje. Si no encuentra a ese id en linea, no hace nada.
  """
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
    Enum.each(miembros, fn usuario_id ->
      enviar_notificacion(:grupo_creado, usuario_id, mensaje)
    end)
    {:ok, "notificaciones distribuidas con exito"}
  end
end
