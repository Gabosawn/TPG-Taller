defmodule Tpg.SanityTest do
  use Tpg.DataCase

  import Tpg.TestHelpers

  test "DataCase funciona correctamente" do
    assert Repo.all(Tpg.Dominio.Receptores.Usuario) == []
  end

  test "TestHelpers funciona correctamente" do
    {:ok, user} = create_test_user("test_user_#{:rand.uniform(9999)}", "password")
    assert user.nombre =~ "test_user"
  end

  test "WebSocket mock funciona" do
    ws = spawn_websocket_mock()
    send(ws, {:test, "hola"})

    assert_receive_websocket(ws, {:test, "hola"}, 1000)
  end
end
