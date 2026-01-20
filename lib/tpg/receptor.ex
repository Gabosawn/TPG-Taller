defmodule Tpg.Receptor do
  use Ecto.Schema
  import Ecto.Changeset
  alias Tpg.Repo, as: Repo

  @primary_key {:receptor_type, :string, autogenerate: false}
  schema "receptores" do
  end

  def changeset(attrs) do

    {estado, changeset} = %Tpg.Receptor{}
    |> cast(attrs, [:receptor_type])
    |> unique_constraint(:receptor_type, name: "receptores_pkey", message: "El tipo de receptor ya existe")
    |> validate_inclusion(:receptor_type, ["Usuario", "Grupo"], message: "El tipo de receptor debe ser 'Usuario' o 'Grupo'")
    |> Repo.insert()

    case estado do
      :ok -> IO.inspect(changeset)
      :error -> IO.inspect(changeset.errors)
    end
  end

end
