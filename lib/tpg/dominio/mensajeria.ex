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
  @spec enviar_mensaje(reciever :: integer(), sender :: integer(), message :: string()) :: {:ok, %{}} | {:error, any()}
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
      {:ok, %{mensaje: mensaje}} ->
        usuario = Repo.get_by(Usuario, receptor_id: sender)
        {:ok, %Tpg.Dominio.Dto.Mensaje{
          id: mensaje.id,
          nombre: usuario.nombre,
          estado: mensaje.estado,
          contenido: mensaje.contenido,
          emisor: sender,
          fecha: mensaje.inserted_at
        }}
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
        join: usuario in Usuario,
        on: usuario.receptor_id == emisor.usuario_id,
        where: receptor.receptor_id == ^grupo_id,
        select: %{
          id: mensaje.id,
          emisor: emisor.usuario_id,
          contenido: mensaje.contenido,
          nombre: usuario.nombre,
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
        select: %Tpg.Dominio.Dto.Mensaje{
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

  def mensajes_por_usuario(usuario_id) do
    mensajes_query =
      from(receptor in Recibido,
        join: mensaje in Mensaje, on: receptor.mensaje_id == mensaje.id,
        join: emisor in Enviado, on: mensaje.id == emisor.mensaje_id,
        join: usuario in Usuario, on: emisor.usuario_id == usuario.receptor_id,
        where: receptor.receptor_id == ^usuario_id,
        where: mensaje.estado == "ENVIADO",
        select: %Tpg.Dominio.Dto.Mensaje{
          id: mensaje.id,
          emisor: emisor.usuario_id,
          nombre: usuario.nombre,
          contenido: mensaje.contenido,
          estado: mensaje.estado,
          fecha: mensaje.inserted_at
        }
      )

    Multi.new()
    |> Multi.all(:mensajes, mensajes_query)
    |> Multi.run(:agrupar, fn _repo, %{mensajes: mensajes} ->
      case mensajes do
        [] -> {:ok, []}
        _ ->
          agrupados = mensajes
          |> Enum.group_by(&(&1.emisor))
          |> Map.to_list()
          |> Enum.map(fn {k, v} ->
            %Tpg.Dominio.Dto.Notificacion{receptor_id: k, tipo: "privado", mensajes: v}
          end)
          {:ok, agrupados}
      end
    end)
    |> Multi.run(:actualizar_estado, fn _repo, %{mensajes: mensajes} ->
      ids = Enum.map(mensajes, & &1.id)

      case ids do
        [] -> {:ok, {0, nil}}
        _ ->
          update_query = from(m in Mensaje, where: m.id in ^ids)
          {:ok, Repo.update_all(update_query, set: [estado: "ENTREGADO", updated_at: DateTime.utc_now()])}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{agrupar: agrupados}} -> agrupados
      {:error, _op, reason, _changes} -> raise reason
    end
  end

  def mensajes_por_grupo(usuario_id) do
    mensajes_query =
      from(usuario in UsuariosGrupo,
        join: receptor in Recibido, on: usuario.grupo_id == receptor.receptor_id,
        join: mensaje in Mensaje, on: receptor.mensaje_id == mensaje.id,
        join: emisor in Enviado, on: mensaje.id == emisor.mensaje_id,
        join: emisor_usuario in Usuario, on: emisor.usuario_id == emisor_usuario.receptor_id,
        where: usuario.usuario_id == ^usuario_id,
        where: mensaje.estado == "ENVIADO",
        select: %{
          id: mensaje.id,
          receptor: receptor.receptor_id,
          emisor: emisor.usuario_id,
          emisor_nombre: emisor_usuario.nombre,
          contenido: mensaje.contenido,
          estado: mensaje.estado,
          fecha: mensaje.inserted_at
        }
      )

    Multi.new()
    |> Multi.all(:mensajes, mensajes_query)
    |> Multi.run(:agrupar, fn _repo, %{mensajes: mensajes} ->
      case mensajes do
        [] -> {:ok, []}
        _ ->
          agrupados = mensajes
          |> Enum.group_by(&(&1.receptor))
          |> Map.to_list()
          |> Enum.map(fn {k, v} ->
            mensajes = Enum.map(v, &Map.delete(&1, :receptor))
            |> Enum.map(fn msg ->
              %Tpg.Dominio.Dto.Mensaje{
                id: msg.id,
                emisor: msg.emisor,
                nombre: msg.emisor_nombre,
                contenido: msg.contenido,
                estado: msg.estado,
                fecha: msg.fecha
              }
            end)

            %Tpg.Dominio.Dto.Notificacion{
              receptor_id: k,
              tipo: "grupo",
              mensajes: mensajes
            }
          end)

          {:ok, agrupados}
      end
    end)
    |> Multi.run(:actualizar_estado, fn _repo, %{agrupar: agrupados} ->
      agrupados
      |> Enum.each(fn grupo ->
        Enum.max_by(grupo.mensajes, & &1.fecha)
        |> Tpg.Dominio.Receptores.marcar_mensaje_entregado(usuario_id, grupo.receptor_id)
      end)
      {:ok, :done}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{agrupar: agrupados}} -> agrupados
      {:error, _op, reason, _changes} -> raise reason
    end
  end

  def actualizar_estado_mensaje(estado, mensaje_id) do
    Repo.get(Mensaje, mensaje_id)
    |> Ecto.Changeset.change(%{estado: estado})
    |> Repo.update()
  end

  def marcar_mensajes_como_leidos(mensajes) do
    Multi.new()
    |> Multi.run(:actualizar_estado, fn _repo, _changes ->
      ids = Enum.map(mensajes, & &1.id)
      case ids do
        [] -> {:ok, {0, nil}}
        _ ->
          update_query = from(m in Mensaje, where: m.id in ^ids)
          {:ok, Repo.update_all(update_query, set: [estado: "VISTO", updated_at: DateTime.utc_now()])}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _results} -> :ok
      {:error, _op, reason, _changes} -> raise reason
    end
  end
end
