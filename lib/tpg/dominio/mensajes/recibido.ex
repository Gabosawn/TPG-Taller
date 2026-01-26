defmodule Tpg.Dominio.Mensajes.Recibido do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recibidos" do
    belongs_to :receptor, Tpg.Dominio.Receptores.Receptor, foreign_key: :receptor_id
    belongs_to :mensaje, Tpg.Dominio.Mensajes.Mensaje, foreign_key: :mensaje_id
    field :recibido_at, :utc_datetime
    field :leido_at, :utc_datetime

    timestamps(updated_at: false)
  end


  def changeset(recibido, attrs) do
    recibido
    |> cast(attrs, [:mensaje_id, :receptor_id, :inserted_at, :leido_at])
    |> validate_required([:mensaje_id, :receptor_id])
    |> foreign_key_constraint(:mensaje_id)
    |> foreign_key_constraint(:receptor_id)
    |> validate_orden_temporal()
  end

  defp validate_orden_temporal(changeset) do
    entregado = get_field(changeset, :inserted_at)
    leido = get_field(changeset, :leido_at)

    cond do
      is_nil(leido) or is_nil(entregado) ->
        changeset

      DateTime.compare(leido, entregado) == :lt ->
        add_error(changeset, :leido_at, "no puede ser anterior a entregado_at")

      true ->
        changeset
    end
  end
end
