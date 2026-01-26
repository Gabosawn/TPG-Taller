defmodule Tpg.Dominio.Mensajeria do
  alias Ecto.Multi
  alias Tpg.Repo
  import Ecto.Query
  alias Tpg.Dominio.Mensajes.{Recibido, Mensaje, Enviado}

  @doc """
  Envia el mismo mensaje a todos los participantes del grupo y marca el mensaje como 'ENVIADO'
  """
  @spec enviar_a_grupo(group_id :: integer(), emisor::integer(), mensaje :: %Mensaje{}, miembros_ids :: Enum.t()) :: {:ok, %Mensaje{}} | {:error, any()}
  def enviar_a_grupo(group_id, emisor, mensaje, miembros_ids) do
    Multi.new()
    |> Multi.insert(:mensaje, fn _ ->
      Mensaje.changeset(mensaje)
    end)
    |> Multi.insert(:enviado, fn %{mensaje: mensaje} ->
      Enviado.changeset(%{
        usuario_id: emisor,
        mensaje_id: mensaje.id
      })
    end)
    |> Multi.insert(:recibido, fn %{mensaje: mensaje} ->
      Recibido.changeset(%Recibido{}, %{
        receptor_id: group_id,
        mensaje_id: mensaje.id
      })
    end)
    # NUEVO: Crear evento por cada miembro del grupo
    |> insertar_eventos_grupo(miembros_ids)
    |> Repo.transaction()
    |> case do
      {:ok, %{mensaje: mensaje}} -> {:ok, mensaje}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  defp insertar_eventos_grupo(multi, miembros_ids) do
    Enum.reduce(miembros_ids, multi, fn miembro_id, acc ->
      Multi.insert(acc, {:recibido, miembro_id}, fn %{mensaje: mensaje} ->
        Recibido.changeset(%Recibido{}, %{
          mensaje_id: mensaje.id,
          receptor_id: miembro_id
        })
      end)
    end)
  end

  @doc """
  Envia el mensaje del emisor al receptor marcandolo como 'ENVIADO'
  """
  @spec enviar_mensaje(reciever :: integer(), sender :: integer(), message :: %Mensaje{}) :: {:ok, %Mensaje{}} | {:error, any()}
  def enviar_mensaje(reciever, sender, message) do
    IO.inspect(%{reciever: reciever, sender: sender, message: message})

    Multi.new()
    |> Multi.insert(:mensaje, fn _ ->
      Mensaje.changeset(message)
    end)
    |> Multi.insert(:enviado, fn %{mensaje: mensaje} ->
      Enviado.changeset(%{
        usuario_id: sender,
        mensaje_id: mensaje.id
      })
    end)
    |> Multi.insert(:recibido, fn %{mensaje: mensaje} ->
      Recibido.changeset(%Recibido{}, %{
        receptor_id: reciever,
        mensaje_id: mensaje.id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{mensaje: mensaje}} -> {:ok, mensaje}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  def get_mensajes(grupo_id) do
    query =
      from(receptor in Recibido,
        join: mensaje in Mensaje,
        on: receptor.mensaje_id == mensaje.id,
        join: emisor in Enviado,
        on: mensaje.id == emisor.mensaje_id,
        where: receptor.receptor_id == ^grupo_id,
        select: %{
          id: mensaje.id,
          emisor: emisor.usuario_id,
          contenido: mensaje.contenido,
          estado: mensaje.estado,
          fecha: mensaje.inserted_at
        },
        order_by: [desc: mensaje.inserted_at]
      )
      |> Repo.all()
    query
  end

  def obtener_mensajes_usuarios(user_1, user_2) do
    mensajes_query =
      from(mensaje in Mensaje,
        join: receptor in Recibido,
        on: mensaje.id == receptor.mensaje_id,
        join: emisor in Enviado,
        on: mensaje.id == emisor.mensaje_id,
        where:
          (receptor.receptor_id == ^user_1 and emisor.usuario_id == ^user_2) or
            (receptor.receptor_id == ^user_2 and emisor.usuario_id == ^user_1),
        select: %{
          id: mensaje.id,
          emisor: emisor.usuario_id,
          contenido: mensaje.contenido,
          estado: mensaje.estado,
          fecha: mensaje.inserted_at
        },
        order_by: [desc: mensaje.inserted_at]
      )

    Repo.all(mensajes_query)
  end
end
