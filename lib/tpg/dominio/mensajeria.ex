defmodule Tpg.Dominio.Mensajeria do
  alias Ecto.Multi
  alias Tpg.Repo
  import Ecto.Query
  alias Tpg.Dominio.Mensajes.{Recibido, Mensaje, Enviado}

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
      Recibido.changeset(%{
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
    query = from( receptor in Recibido,
      join: mensaje in Mensaje, on: receptor.mensaje_id == mensaje.id,
      join: emisor in Enviado, on: mensaje.id == emisor.mensaje_id,
      where: receptor.receptor_id == ^grupo_id,
      select: %{
        id: mensaje.id,
        emisor: emisor.usuario_id,
        contenido: mensaje.contenido,
        estado: mensaje.estado,
        fecha: mensaje.inserted_at
      },
      order_by: [desc: mensaje.inserted_at])
    |> Repo.all()
  end

  def obtener_mensajes_usuarios(user_1, user_2) do
    mensajes_query = from(mensaje in Mensaje,
      join: receptor in Recibido, on: mensaje.id == receptor.mensaje_id,
      join: emisor in Enviado, on: mensaje.id == emisor.mensaje_id,
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
