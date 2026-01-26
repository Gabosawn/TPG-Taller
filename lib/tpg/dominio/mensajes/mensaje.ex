defmodule Tpg.Dominio.Mensajes.Mensaje do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mensajes" do
    field :contenido, :string
    field :estado, :string
    timestamps()
    has_many :recibido, Tpg.Dominio.Mensajes.Recibido
  end

  def changeset(attrs) do
    cast(%Tpg.Dominio.Mensajes.Mensaje{}, attrs, [:contenido, :estado])
    |> validate_required([:contenido])
  end
end
