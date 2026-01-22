defmodule Tpg.Receptores.Receptor do
  use Ecto.Schema

  schema "receptores" do
    field :tipo, :string
    timestamps()
  end
end
