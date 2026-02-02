defmodule Tpg.Services.NotificationService do
  require Logger
  alias Tpg.Repo
  alias Tpg.Dominio.Mensajes.{Recibido, Enviado, Mensaje}
  alias Tpg.Dominio.Receptores
  alias Tpg.Dominio.Receptores.Usuario
  alias Tpg.Services.SessionService
  import Ecto.Query

  @doc """
  Notifica a un usuario o grupo de usuarios 'en_linea' sobre un nuevo mensaje
  """
  @spec notificar(:mensaje, contexto:: %{usuarios: [integer()], mensaje: %{}, chat_pid: pid()}) :: nil
  def notificar(:mensaje, contexto) do
    Enum.each(contexto.usuarios, fn usuario ->
      if SessionService.en_linea?(usuario) do
        spawn(fn  ->
          notificar_mensaje(usuario, contexto, contexto.chat_pid)
        end)
      end
    end)
  end
  defp notificar_mensaje(id_usuario, contexto, chat_pid) do
    Logger.debug("[notification] notificando a usuario #{id_usuario} el mensaje: #{contexto.mensaje.contenido}")
    case SessionService.esta_escuchando?(id_usuario, chat_pid) do
      true -> notificar_mensaje_en_bandeja(id_usuario, contexto)
      false -> notificar_mensaje_con_push(id_usuario, contexto)
    end
  end

  # Para notificar a un cliente en linea que una de sus conversaciones tiene un mensaje
  @spec notificar_mensaje_en_bandeja(pid :: pid, mensaje :: String.t()) :: nil
  defp notificar_mensaje_en_bandeja(id_usuario, contexto) do
    SessionService.notificar_mensaje(id_usuario, :notificacion_bandeja, contexto)
  end
  # Para notificar a un cliente que el chat que esta utilizando tiene un nuevo mensaje
  @spec notificar_mensaje_con_push(id_usuario:: integer(), contexto:: map()) :: nil
  defp notificar_mensaje_con_push(id_usuario, contexto) do
    SessionService.notificar_mensaje(id_usuario, :nuevo_mensaje_privado, contexto)
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
    usuarios =
      Tpg.Dominio.Mensajeria.mensajes_por_usuario(id_usuario)
      |> Enum.group_by(&(&1.emisor))
      |> Map.to_list()
      |> Enum.map(fn {k, v} ->
        %{receptor_id: k, tipo: "privado", mensajes: v}
      end)

    grupos =
      Tpg.Dominio.Mensajeria.mensajes_por_grupo(id_usuario)
      |> Enum.group_by(&(&1.receptor))
      |> Map.to_list()
      |> Enum.map(fn {k, v} ->
        %{
          receptor_id: k,
          tipo: "grupo",
          mensajes: Enum.map(v, &Map.delete(&1, :receptor))
        }
      end)
      |> Enum.concat(usuarios)
      |> Enum.sort_by(fn %{mensajes: mensajes} ->
        mensajes
        |> Enum.max_by(& &1.fecha, fn -> %{fecha: ~N[0000-01-01 00:00:00]} end)
        |> Map.get(:fecha)
      end, :desc)
      |> IO.inspect(label: "Notificaciones para el usuario #{id_usuario}")
  end
end
