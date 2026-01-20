defmodule Tpg.Usuario do
  use Ecto.Schema
  import Ecto.Changeset
  alias Tpg.Repo, as: Repo

  @primary_key {:nombre, :string, autogenerate: false}
  schema "usuarios" do
    field :contrasenia, :string
    belongs_to :receptores, Tpg.Receptor, foreign_key: :tipo, references: :receptor_type, type: :string
  end

  def changeset(tipoOperacion, attrs) do
    changeset = cast(%Tpg.Usuario{}, attrs, [:nombre, :contrasenia, :tipo])

    case tipoOperacion do
      :crear -> crear_usuario(changeset)
      _ -> {:error, "Operación no soportada"}
    end

  end

  def crear_usuario(changeset) do
    changeset
    |> validate_required([:nombre, :contrasenia, :tipo], message: "El campo es obligatorio")
    |> unique_constraint(:nombre, name: "usuarios_pkey", message: "El nombre de usuario ya existe")
    |> validate_format(:nombre, ~r/^[a-zA-Z0-9]+$/, mensaje: "El nombre de usuario debe ser alfanumérico")
    |> check_constraint(:nombre, name: "nombre_alfanumerico", message: "El nombre de usuario debe ser alfanumérico")
    |> validate_length(:nombre, min: 8, max: 50)
    |> check_constraint(:nombre, name: "tamanio_nombre", message: "El nombre debe tener entre 8 y 50 caracteres")
    |> validate_length(:contrasenia, min: 8, max: 50)
    |> check_constraint(:contrasenia, name: "contrasenia_longitud", message: "La contraseña debe tener entre 8 y 50 caracteres")
    |> validate_format(:contrasenia, ~r/[¡!-.*=@]/, mensaje: "La contraseña debe contener al menos un carácter especial")
    |> IO.inspect()
    |> check_constraint(:contrasenia, name: "contrasenia_especial", message: "La contraseña debe contener al menos un carácter especial")
    |> validate_format(:contrasenia, ~r/[A-Z]/, mensaje: "La contraseña debe contener al menos una letra mayúscula")
    |> check_constraint(:contrasenia, name: "contrasenia_mayuscula", message: "La contraseña debe contener al menos una letra mayúscula")
    |> validate_format(:contrasenia, ~r/[a-z]/, mensaje: "La contraseña debe contener al menos una letra minúscula")
    |> check_constraint(:contrasenia, name: "contrasenia_minuscula", message: "La contraseña debe contener al menos una letra minúscula")
    |> validate_format(:contrasenia, ~r/^\S+$/, mensaje: "La contraseña no debe contener espacios en blanco")
    |> check_constraint(:contrasenia, name: "contrasenia_sin_espacios", message: "La contraseña no debe contener espacios")
    |> validate_format(:contrasenia, ~r/[0-9]/, mensaje: "La contraseña debe contener al menos un número")
    |> check_constraint(:contrasenia, name: "contrasenia_numero", message: "La contraseña debe contener al menos un número")
    |> Repo.insert()
  end

end
