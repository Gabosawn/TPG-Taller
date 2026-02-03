defmodule Tpg.SanityTest do
  use Tpg.DataCase

  import Tpg.TestHelpers

  test "DataCase funciona correctamente" do
    assert Repo.all(Tpg.Dominio.Receptores.Usuario) == []
  end

  test "TestHelpers funciona correctamente" do
    {:ok, user} = create_test_user("testuser#{:rand.uniform(9999)}", "Password@1")
    assert user.nombre =~ "testuser"
  end

  test "WebSocket mock funciona" do
    ws = spawn_websocket_mock()
    send(ws, {:test, "hola"})

    assert_receive_websocket(ws, {:test, "hola"}, 1000)
  end
end
