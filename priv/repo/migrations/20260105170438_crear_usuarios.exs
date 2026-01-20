defmodule Tpg.Repo.Migrations.CrearUsuarios do
  use Ecto.Migration

  def change do
    create table(:usuarios, primary_key: false) do
      add :nombre, :varchar, size: 50, null: false, primary_key: true
      add :contrasenia, :varchar, size: 50, null: false
      add :tipo, references(:receptores, column: :receptor_type, type: :varchar), null: false
    end

    create unique_index(:usuarios, [:nombre])

    create constraint(:usuarios, :nombre_alfanumerico, check: "nombre ~ '^[a-zA-Z0-9]+$'")
    create constraint(:usuarios, :tamanio_nombre, check: "length(nombre) >= 8 AND length(nombre) <= 50")

    create constraint(:usuarios, :contrasenia_longitud, check: "char_length(contrasenia) >= 8 AND char_length(contrasenia) <= 50")
    create constraint(:usuarios, :contrasenia_sin_espacios, check: "contrasenia !~ '\\s'")
    create constraint(:usuarios, :contrasenia_especial, check: "contrasenia ~ '[¡!-.*=@]'")
    create constraint(:usuarios, :contrasenia_mayuscula, check: "contrasenia ~ '[A-Z]'")
    create constraint(:usuarios, :contrasenia_minuscula, check: "contrasenia ~ '[a-z]'")
    create constraint(:usuarios, :contrasenia_numero, check: "contrasenia ~ '[0-9]'")
  end
end
