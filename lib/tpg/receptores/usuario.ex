defmodule Tpg.Receptores.Usuario do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Tpg.Repo

  @primary_key false
  schema "usuarios" do
    belongs_to :receptores, Tpg.Receptores.Receptor, foreign_key: :receptor_id, primary_key: true
    field :nombre, :string
    field :contrasenia, :string
    field :ultima_conexion, :utc_datetime
  end

  def changeset(tipoOperacion, attrs) do
    changeset = cast(%Tpg.Receptores.Usuario{}, attrs, [:receptor_id, :nombre, :contrasenia])
    |> IO.inspect()
    case tipoOperacion do
      :crear -> crear_usuario(changeset)
      :conectar -> obtener_usuario(attrs)
      :listar -> listar_usuarios()
      _ -> {:error, "Operación no soportada"}
    end

  end

  def existe?(id) do
    Repo.get(Tpg.Receptores.Usuario, id) != nil
  end

  def listar_usuarios() do
    Repo.all(from u in Tpg.Receptores.Usuario, select: %{nombre: u.nombre, receptor_id: u.receptor_id})
  end

  def obtener_usuario(attrs) do
    Repo.get_by(Tpg.Receptores.Usuario, [nombre: attrs.nombre, contrasenia: attrs.contrasenia])
    |> cast(%{}, [])
    |> put_change(:ultima_conexion, DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  def crear_usuario(changeset) do
    changeset
    |> validate_required([:receptor_id, :nombre, :contrasenia], message: "El campo es obligatorio")
    |> put_change(:ultima_conexion, DateTime.utc_now() |> DateTime.truncate(:second))
    |> unique_constraint(:nombre, name: "usuarios_nombre_index", message: "El nombre de usuario ya existe")
    |> validate_format(:nombre, ~r/^[a-zA-Z0-9]+$/, mensaje: "El nombre de usuario debe ser alfanumérico")
    |> check_constraint(:nombre, name: "nombre_alfanumerico", message: "El nombre de usuario debe ser alfanumérico")
    |> validate_length(:nombre, min: 8, max: 50)
    |> check_constraint(:nombre, name: "tamanio_nombre", message: "El nombre debe tener entre 8 y 50 caracteres")
    |> validate_length(:contrasenia, min: 8, max: 50)
    |> check_constraint(:contrasenia, name: "contrasenia_longitud", message: "La contraseña debe tener entre 8 y 50 caracteres")
    |> validate_format(:contrasenia, ~r/[¡!-.*=@]/, mensaje: "La contraseña debe contener al menos un carácter especial")
    |> check_constraint(:contrasenia, name: "contrasenia_especial", message: "La contraseña debe contener al menos un carácter especial")
    |> validate_format(:contrasenia, ~r/[A-Z]/, mensaje: "La contraseña debe contener al menos una letra mayúscula")
    |> check_constraint(:contrasenia, name: "contrasenia_mayuscula", message: "La contraseña debe contener al menos una letra mayúscula")
    |> validate_format(:contrasenia, ~r/[a-z]/, mensaje: "La contraseña debe contener al menos una letra minúscula")
    |> check_constraint(:contrasenia, name: "contrasenia_minuscula", message: "La contraseña debe contener al menos una letra minúscula")
    |> validate_format(:contrasenia, ~r/^\S+$/, mensaje: "La contraseña no debe contener espacios en blanco")
    |> check_constraint(:contrasenia, name: "contrasenia_sin_espacios", message: "La contraseña no debe contener espacios")
    |> validate_format(:contrasenia, ~r/[0-9]/, mensaje: "La contraseña debe contener al menos un número")
    |> check_constraint(:contrasenia, name: "contrasenia_numero", message: "La contraseña debe contener al menos un número")
  end

  def agregar_contacto(id_usuario, nombre_usuario) do
    with {:ok, usuario} <- validar_usuario_existe(id_usuario),
        {:ok, contacto} <- validar_contacto_existe(nombre_usuario) do
      # Aquí puedes agregar la lógica para insertar en la tabla de contactos
      {:ok, %{usuario: usuario, contacto: contacto}}
    else
      {:error, :usuario_no_existe} ->
        {:error, "El usuario con ID #{id_usuario} no existe"}
      {:error, :contacto_no_existe} ->
        {:error, "El usuario '#{nombre_usuario}' no existe"}
      error ->
        error
    end
  end

  defp validar_usuario_existe(id_usuario) do
    case Repo.get(Tpg.Receptores.Usuario, id_usuario) do
      nil -> {:error, :usuario_no_existe}
      usuario -> {:ok, usuario}
    end
  end

  defp validar_contacto_existe(nombre_usuario) do
    case Repo.get_by(Tpg.Receptores.Usuario, nombre: nombre_usuario) do
      nil -> {:error, :contacto_no_existe}
      contacto -> {:ok, contacto}
    end
  end
end
