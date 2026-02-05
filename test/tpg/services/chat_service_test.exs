defmodule Tpg.Services.ChatServiceTest do
  use Tpg.DataCase, async: false

  alias Tpg.Dominio.{Receptores, Mensajeria}
  alias Tpg.Services.ChatService

  setup do
    {:ok, usuario1} = Receptores.crear_usuario(%{nombre: "usuario1", contrasenia: "Contrasenia@1"})
    {:ok, usuario2} = Receptores.crear_usuario(%{nombre: "usuario2", contrasenia: "Contrasenia@2"})
    {:ok, usuario3} = Receptores.crear_usuario(%{nombre: "usuario3", contrasenia: "Contrasenia@3"})

    {:ok, grupo} =
      Receptores.crear_grupo(%{nombre: "grupo_test"}, [usuario1.receptor_id, usuario2.receptor_id])

    {:ok, _agenda} =
      Receptores.agregar_contacto(usuario1.receptor_id, usuario2.nombre)

    {:ok, _} = Tpg.habilitar_canales(usuario1.receptor_id)

    {:ok,
     usuario1: usuario1,
     usuario2: usuario2,
     usuario3: usuario3,
     grupo: grupo}
  end

  describe "Enviar mensajes" do
    test "Envio de mensaje a grupo existente", %{usuario1: usuario1, grupo: grupo} do
      assert {:ok, "mensaje enviado"} =
               ChatService.enviar("grupo", usuario1.receptor_id, grupo.receptor_id, "hola grupo")

      mensajes = Mensajeria.get_mensajes(grupo.receptor_id)

      assert length(mensajes) == 1
      assert Enum.at(mensajes, 0).contenido == "hola grupo"
      assert Enum.at(mensajes, 0).emisor == usuario1.receptor_id
    end

    test "Envio de mensaje a usuario existente", %{usuario1: usuario1, usuario2: usuario2} do
      assert {:ok, "mensaje enviado"} =
               ChatService.enviar(
                 "privado",
                 usuario1.receptor_id,
                 usuario2.receptor_id,
                 "hola privado"
               )
      mensajes = Mensajeria.obtener_mensajes_usuarios(usuario1.receptor_id, usuario2.receptor_id)

      assert length(mensajes) == 1
      assert Enum.at(mensajes, 0).contenido == "hola privado"
      assert Enum.at(mensajes, 0).emisor == usuario1.receptor_id
    end

    test "Envio de mensaje a usuario inexistente", %{usuario1: usuario1} do
      assert {:noproc, _} =
               catch_exit(
                 ChatService.enviar("privado", usuario1.receptor_id, -1, "hola privado")
               )

      mensajes = Mensajeria.obtener_mensajes_usuarios(usuario1.receptor_id, -1)
      assert length(mensajes) == 0
    end

    test "Envio de mensaje a grupo inexistente", %{usuario1: usuario1} do
      assert {:noproc, _} =
               catch_exit(ChatService.enviar("grupo", usuario1.receptor_id, -1, "hola grupo"))

      mensajes = Mensajeria.get_mensajes(-1)

      assert length(mensajes) == 0
    end

    test "Envio de mensaje de grupo con contenido vacío", %{usuario1: usuario1, grupo: grupo} do
      assert {:error, %Ecto.Changeset{}} =
               ChatService.enviar("grupo", usuario1.receptor_id, grupo.receptor_id, "")
    end

    test "Envio de mensaje privado con contenido vacío", %{usuario1: usuario1, usuario2: usuario2} do
      assert {:error, %Ecto.Changeset{}} =
               ChatService.enviar("privado", usuario1.receptor_id, usuario2.receptor_id, "")
    end

  end

  describe "Crear grupo" do
    test "Crear grupo con miembros válidos", %{usuario1: usuario1, usuario2: usuario2, usuario3: usuario3} do
      assert {:ok, grupo} =
               ChatService.crear_grupo("nuevo_grupo", [
                usuario1.receptor_id,
                usuario2.receptor_id,
                usuario3.receptor_id
               ])

      assert grupo.nombre == "nuevo_grupo"
      assert length(Receptores.obtener_miembros(grupo.receptor_id)) == 3
    end

    test "Crear grupo con miembros invalidos", %{usuario1: usuario1, usuario2: usuario2} do
      assert {:error, mensaje} =
               ChatService.crear_grupo("nuevo_grupo", [
                 usuario1.receptor_id,
                 usuario2.receptor_id,
                 -1
               ])
      assert mensaje == "Algunos miembros no existen"
    end
  end

  describe "Validaciones y consultas" do
    test "Validar miembros existentes", %{usuario1: usuario1, usuario2: usuario2} do
      assert {:ok, miembros} =
               ChatService.validate_miembros([
                 usuario1.receptor_id,
                 usuario2.receptor_id,
                 usuario1.receptor_id
               ])
    end

    test "Validar miembros inexistentes", %{usuario1: usuario1, usuario2: usuario2} do
      assert {:error, "Algunos miembros no existen"} =
               ChatService.validate_miembros([
                 usuario1.receptor_id,
                 usuario2.receptor_id,
                 -1
               ])
    end

    test "Obtener conversaciones de un usuario", %{usuario1: usuario1, usuario2: usuario2, grupo: grupo} do
      conversaciones = ChatService.obtener_conversaciones(usuario1.receptor_id)

      assert Enum.any?(conversaciones, fn conv ->
               conv.tipo == "privado" and conv.id == usuario2.receptor_id
             end)

      assert Enum.any?(conversaciones, fn conv ->
               conv.tipo == "grupo" and conv.id == grupo.receptor_id
             end)
    end

    test "Obtener conversaciones de usuario inexistente" do
      assert [] = ChatService.obtener_conversaciones(-1)
    end
  end

  describe "Mostrar y buscar mensajes" do
    test "Mostrar mensajes de grupo", %{usuario1: usuario1, usuario2: usuario2, grupo: grupo} do
      assert {:ok, "mensaje enviado"} =
               ChatService.enviar("grupo", usuario1.receptor_id, grupo.receptor_id, "hola grupo")

      assert {:ok, mensajes, _pid} =
               ChatService.mostrar_mensajes("grupo", usuario2.receptor_id, grupo.receptor_id)

      assert Enum.any?(mensajes, fn msg -> msg.contenido == "hola grupo" end)
    end

    test "Mostrar mensajes privado", %{usuario1: usuario1, usuario2: usuario2} do
      assert {:ok, "mensaje enviado"} =
               ChatService.enviar(
                 "privado",
                 usuario1.receptor_id,
                 usuario2.receptor_id,
                 "hola privado"
               )

      assert {:ok, mensajes, _pid} =
               ChatService.mostrar_mensajes("privado", usuario1.receptor_id, usuario2.receptor_id)

      assert Enum.any?(mensajes, fn msg -> msg.contenido == "hola privado" end)
    end

    test "Buscar mensajes async en privado", %{usuario1: usuario1, usuario2: usuario2} do
      assert {:ok, "mensaje enviado"} =
               ChatService.enviar(
                 "privado",
                 usuario1.receptor_id,
                 usuario2.receptor_id,
                 "mensaje buscado"
               )

      ChatService.buscar_mensajes_async(
        "privado",
        usuario1.receptor_id,
        usuario2.receptor_id,
        "buscado",
        self()
      )

      assert_receive {:resultado_busqueda, {:mensajes_buscados, mensajes}}
      assert Enum.any?(mensajes, fn msg -> msg.contenido == "mensaje buscado" end)
    end

    test "Buscar mensajes async sin resultados", %{usuario1: usuario1, usuario2: usuario2} do
      ChatService.buscar_mensajes_async(
        "privado",
        usuario1.receptor_id,
        usuario2.receptor_id,
        "no-existe",
        self()
      )

      assert_receive {:resultado_busqueda, {:error, "No se encontraron mensajes que coincidan con la búsqueda."}}
    end
  end
end
