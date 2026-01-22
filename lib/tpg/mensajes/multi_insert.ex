defmodule Tpg.Mensajes.MultiInsert do
  alias Ecto.Multi
  alias Tpg.Repo

  def enviar_mensaje(reciever, sender, message) do
    Multi.new()
    |> Multi.insert(:mensaje, fn _ ->
      Tpg.Mensajes.Mensaje.changeset(message)
    end)
    |> Multi.insert(:enviado, fn %{mensaje: mensaje} ->
      Tpg.Mensajes.Enviado.changeset(%{
        usuario_id: sender,
        mensaje_id: mensaje.id
      })
    end)
    |> Multi.insert(:recibido, fn %{mensaje: mensaje} ->
      Tpg.Mensajes.Recibido.changeset(%{
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

end
