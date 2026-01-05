defmodule Tpg.Repo.Migrations.CrearUsuarios do
  use Ecto.Migration

  def change do
    create table("usuario", primary_key: false) do
      add :receptor_id, references(:receptor), primary_key: true, null: false
      add :contrasenia, :string, size: 50, null: false
    end

    create constraint("usuario", :contrasenia_especial, check: "contrasenia ~ '[!@#$%^&*(),.?\":{}|<>]'")
    create constraint("usuario", :contrasenia_sin_espacios, check: "contrasenia !~ '\\s'")
    create constraint("usuario", :contrasenia_mayuscula, check: "contrasenia ~ '[A-Z]'")
    create constraint("usuario", :contrasenia_minuscula, check: "contrasenia ~ '[a-z]'")
    create constraint("usuario", :contrasenia_numero, check: "contrasenia ~ '[0-9]'")
  end
end
