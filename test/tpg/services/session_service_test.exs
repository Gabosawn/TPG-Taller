defmodule Tpg.Services.SessionServiceTest do
  use Tpg.DataCase
  alias Tpg.Services.SessionService
  alias Tpg.Dominio.Receptores

  describe "loggear/2" do
    test "se crea usuario correctamente" do
      usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
      {:ok, usuario_respuesta} = SessionService.loggear(:crear, usuario)
      assert Process.alive?(usuario_respuesta.pid)
      assert is_integer(usuario_respuesta.id)

      assert Receptores.obtener_usuario(usuario) != nil
    end
  end

end
