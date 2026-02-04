defmodule Tpg.Services.SessionServiceTest do
  use Tpg.DataCase
  alias Tpg.Services.SessionService
  alias Tpg.Dominio.Receptores

  describe "Registar, conectar y desconectar" do
    test "se crea usuario correctamente ya loggeado" do
      usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
      {:ok, usuario_respuesta} = SessionService.loggear(:crear, usuario)
      assert Process.alive?(usuario_respuesta.pid)
      assert is_integer(usuario_respuesta.id)

      assert Receptores.obtener_usuario(usuario) != nil
    end
  end

  test "se puede desloggear un usuario" do
      usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
      {:ok, usuario_respuesta} = SessionService.loggear(:crear, usuario)

      {:ok, pid} = SessionService.desloggear(usuario_respuesta.id)
      assert !Process.alive?(pid)
      assert !Process.alive?(usuario_respuesta.pid)
  end

  test "no se puede desloggear a un usuario desloggeado" do
      usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
      {:ok, usuario_respuesta} = SessionService.loggear(:crear, usuario)

      {:ok, _pid} = SessionService.desloggear(usuario_respuesta.id)
      {:error, :not_found} = SessionService.desloggear(usuario_respuesta.id)
  end

  test "se puede conectar la sesion de un usuario luego de desconectarse" do
    usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
    {:ok, usuario_respuesta} = SessionService.loggear(:crear, usuario)
    {:ok, pid} = SessionService.desloggear(usuario_respuesta.id)
    assert !Process.alive?(pid)

    {:ok, usuario_reloggeado} = SessionService.loggear(:conectar, usuario)
    assert Process.alive?(usuario_reloggeado.pid)
  end

  test "No se puede conectar a un usuario inexistente" do
    usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
    {:error, :invalid_credentials} = SessionService.loggear(:conectar, usuario)
  end
  test "No se puede conectar a un usuario con una contrasenia diferente" do
    usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@2"}
    {:error, :invalid_credentials} = SessionService.loggear(:conectar, usuario)
  end
  test "no se puede loggear a un usuario ya loggeado" do
    usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
    {:ok, usuario_respuesta} = SessionService.loggear(:crear, usuario)
    {:error, {:already_started, pid}} = SessionService.loggear(:conectar, usuario)
    assert pid == usuario_respuesta.pid
  end

  test "no se puede crear un usuario con un nombre ocuopado" do
    usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
    {:ok, usuario_respuesta} = SessionService.loggear(:crear, usuario)
    usuario2 = %{nombre: "usuarioValido", contrasenia: "OtraContrasenia@1"}
    {:error, {:nombre, _}} = SessionService.loggear(:crear, usuario2)
  end

  test "no se puede crear un usuario con credenciales invalidas" do
    usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
    # Test con nombre vacio
    {:error, {:nombre, _}} = SessionService.loggear(:crear, %{usuario | nombre: ""})
    # Test con nombre con caracteres especiales
    {:error, {:nombre, _}} = SessionService.loggear(:crear, %{usuario | nombre: "usuario_valido"})

    # Test con contrasenia corta
    {:error, {:contrasenia, _}} = SessionService.loggear(:crear, %{usuario | contrasenia: "weak"})
    # Test con contrasenia sin mayuscula
    {:error, {:contrasenia, _}} = SessionService.loggear(:crear, %{usuario | contrasenia: "contrasenia@1"})
      # Test con contrasenia sin caracter especial
    {:error, {:contrasenia, _}} = SessionService.loggear(:crear, %{usuario | contrasenia: "Contrasenia1"})
      # Test con contrasenia sin numero
    {:error, {:contrasenia, _}} = SessionService.loggear(:crear, %{usuario | contrasenia: "Contrasenia@"})
  end
end
