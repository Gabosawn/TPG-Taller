defmodule Tpg.Dominio.Mensajeria do
  require Logger
  alias Ecto.Multi
  alias Tpg.Repo
  import Ecto.Query
  alias Tpg.Dominio.Mensajes.{Recibido, Mensaje, Enviado}
  alias Tpg.Dominio.Receptores.{Usuario, UsuariosGrupo}

  def obtener_kv_user_ids_nombres(id_grupo) do
    from(u in Tpg.Dominio.Receptores.Usuario,
      join: ug in "usuarios_grupo",
      on: ug.usuario_id == u.receptor_id,
      where: ug.grupo_id == ^id_grupo,
      select: {u.receptor_id, u.nombre}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Envia el mensaje del emisor al receptor marcandolo como 'ENVIADO'
  """
  @spec enviar_mensaje(reciever :: integer(), sender :: integer(), message :: string()) :: {:ok, %Mensaje{}} | {:error, any()}
  def enviar_mensaje(reciever, sender, message) do
    Multi.new()
    |> Multi.insert(:mensaje, fn _ ->
      Mensaje.changeset(%{contenido: message})
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

  def obtener_mensajes_estado_enviado(usuario_id) do
    mensajes_por_usuario(usuario_id) ++ mensajes_por_grupo(usuario_id)
  end

  def mensajes_por_usuario(usuario_id) do
    from(receptor in Recibido,
      join: mensaje in Mensaje, on: receptor.mensaje_id == mensaje.id,
      join: emisor in Enviado, on: mensaje.id == emisor.mensaje_id,
      join: usuario in Usuario, on: emisor.usuario_id == usuario.receptor_id,
      where: receptor.receptor_id == ^usuario_id,
      select: %{
        id: mensaje.id,
        emisor: emisor.usuario_id,
        emisor_nombre: usuario.nombre,
        contenido: mensaje.contenido,
        estado: mensaje.estado,
        fecha: mensaje.inserted_at
      }
    ) |> Repo.all()
  end

  def mensajes_por_grupo(usuario_id) do
    from(usuario in UsuariosGrupo,
      join: receptor in Recibido, on: usuario.grupo_id == receptor.receptor_id,
      join: mensaje in Mensaje, on: receptor.mensaje_id == mensaje.id,
      join: emisor in Enviado, on: mensaje.id == emisor.mensaje_id,
      join: emisor_usuario in Usuario, on: emisor.usuario_id == emisor_usuario.receptor_id,
      where: usuario.usuario_id == ^usuario_id,
      select: %{
        id: mensaje.id,
        receptor: receptor.receptor_id,
        emisor: emisor.usuario_id,
        emisor_nombre: emisor_usuario.nombre,
        contenido: mensaje.contenido,
        estado: mensaje.estado,
        fecha: mensaje.inserted_at
      }
    ) |> Repo.all()
  end

  def actualizar_estado_mensaje(estado, mensaje_id) do
    Repo.get(Mensaje, mensaje_id)
    |> Ecto.Changeset.change(%{estado: estado})
    |> Repo.update()
  end
end
