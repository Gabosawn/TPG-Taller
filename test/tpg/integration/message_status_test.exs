defmodule Tpg.Integration.MessageStatusTest do
  use Tpg.DataCase
  import Tpg.TestHelpers

  alias Tpg.Services.{ChatService, SessionService, NotificationService}
  alias Tpg.Dominio.Mensajeria

  setup do
    # Crear usuarios de prueba
    {:ok, user1} = create_test_user("alice", "password123")
    {:ok, user2} = create_test_user("bob", "password456")

    # Iniciar sesiones
    {:ok, session1} = SessionService.loggear(:conectar, user1)
    {:ok, session2} = SessionService.loggear(:conectar, user2)

    # Crear WebSockets mock
    ws1 = spawn_websocket_mock()
    ws2 = spawn_websocket_mock()

    SessionService.registrar_cliente(session1.id, ws1)
    SessionService.registrar_cliente(session2.id, ws2)

    on_exit(fn ->
      SessionService.desloggear(session1.id)
      SessionService.desloggear(session2.id)
    end)

    %{
      user1: user1,
      user2: user2,
      session1: session1,
      session2: session2,
      ws1: ws1,
      ws2: ws2
    }
  end

  describe "Estado ENVIADO" do
    test "mensaje se crea con estado ENVIADO", %{user1: user1, user2: user2} do
      {:ok, _} = ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "Hola")

      mensajes = Mensajeria.obtener_mensajes_usuarios(user1.receptor_id, user2.receptor_id)
      mensaje = List.first(mensajes)

      assert mensaje.estado == "ENVIADO"
    end

    test "emisor no recibe notificación de estado ENVIADO", %{user1: user1, user2: user2, ws1: ws1} do
      ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "Test")

      refute_receive {:estado_mensaje_actualizado, _, "ENVIADO"}, 500
    end
  end

  describe "Estado RECIBIDO" do
    test "mensaje pasa a RECIBIDO cuando destinatario está en línea", %{
      user1: user1,
      user2: user2,
      ws2: ws2
    } do
      # Enviar mensaje
      {:ok, _} = ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "Mensaje")

      # Esperar que el destinatario lo reciba
      assert_receive_websocket(ws2, {:nuevo_mensaje, _}, 1000)

      # Verificar que pasó a RECIBIDO
      :timer.sleep(100)
      mensajes = Mensajeria.obtener_mensajes_usuarios(user1.receptor_id, user2.receptor_id)
      mensaje = List.first(mensajes)

      assert mensaje.estado == "RECIBIDO"
    end

    test "emisor recibe notificación de RECIBIDO", %{
      user1: user1,
      user2: user2,
      ws1: ws1
    } do
      {:ok, _} = ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "Test")

      assert_receive_websocket(ws1, {:estado_mensaje_actualizado, msg_id, "RECIBIDO"}, 2000)
      assert is_integer(msg_id)
    end

    test "mensaje NO pasa a RECIBIDO si destinatario está offline", %{
      user1: user1,
      user2: user2,
      session2: session2
    } do
      # Desconectar user2
      SessionService.desloggear(session2.id)

      # Enviar mensaje
      {:ok, _} = ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "Offline msg")

      mensajes = Mensajeria.obtener_mensajes_usuarios(user1.receptor_id, user2.receptor_id)
      mensaje = List.first(mensajes)

      assert mensaje.estado == "ENVIADO"
    end
  end

  describe "Estado LEIDO/VISTO" do
    test "mensajes pasan a VISTO al abrir chat", %{
      user1: user1,
      user2: user2,
      ws2: ws2
    } do
      # Enviar varios mensajes
      ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "Msg 1")
      ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "Msg 2")
      :timer.sleep(200)

      # User2 abre el chat
      SessionService.oir_chat("privado", user2.receptor_id, user1.receptor_id, ws2)

      # Verificar que los mensajes pasaron a VISTO
      :timer.sleep(300)
      mensajes = Mensajeria.obtener_mensajes_usuarios(user1.receptor_id, user2.receptor_id)

      Enum.each(mensajes, fn msg ->
        if msg.emisor == user1.receptor_id do
          assert msg.estado == "VISTO"
        end
      end)
    end

    test "emisor recibe notificación de VISTO", %{
      user1: user1,
      user2: user2,
      ws1: ws1,
      ws2: ws2
    } do
      {:ok, _} = ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "Test")
      :timer.sleep(100)

      # User2 abre el chat
      SessionService.oir_chat("privado", user2.receptor_id, user1.receptor_id, ws2)

      # Emisor debe recibir notificación
      assert_receive_websocket(ws1, {:estado_mensaje_actualizado, _, "VISTO"}, 2000)
    end

    test "solo se marcan como VISTO los mensajes del otro usuario", %{
      user1: user1,
      user2: user2,
      ws1: ws1
    } do
      # User1 envía mensajes
      ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "De user1")
      # User2 envía mensajes
      ChatService.enviar("privado", user2.receptor_id, user1.receptor_id, "De user2")
      :timer.sleep(200)

      # User1 abre el chat
      SessionService.oir_chat("privado", user1.receptor_id, user2.receptor_id, ws1)
      :timer.sleep(300)

      mensajes = Mensajeria.obtener_mensajes_usuarios(user1.receptor_id, user2.receptor_id)

      # Solo el mensaje DE user2 debe estar VISTO desde la perspectiva de user1
      msg_de_user2 = Enum.find(mensajes, fn m -> m.emisor == user2.receptor_id end)
      msg_de_user1 = Enum.find(mensajes, fn m -> m.emisor == user1.receptor_id end)

      assert msg_de_user2.estado == "VISTO"
      # El mensaje propio permanece en su estado
      refute msg_de_user1.estado == "VISTO"
    end
  end

  describe "Flujo completo" do
    test "ciclo completo ENVIADO -> RECIBIDO -> VISTO", %{
      user1: user1,
      user2: user2,
      ws1: ws1,
      ws2: ws2
    } do
      # 1. Enviar mensaje (ENVIADO)
      {:ok, _} = ChatService.enviar("privado", user1.receptor_id, user2.receptor_id, "Ciclo completo")

      mensajes = Mensajeria.obtener_mensajes_usuarios(user1.receptor_id, user2.receptor_id)
      mensaje = List.first(mensajes)
      assert mensaje.estado == "ENVIADO"

      # 2. Destinatario recibe (RECIBIDO)
      :timer.sleep(200)
      assert_receive_websocket(ws2, {:nuevo_mensaje, _})
      assert_receive_websocket(ws1, {:estado_mensaje_actualizado, _, "RECIBIDO"})

      mensajes = Mensajeria.obtener_mensajes_usuarios(user1.receptor_id, user2.receptor_id)
      mensaje = List.first(mensajes)
      assert mensaje.estado == "RECIBIDO"

      # 3. Destinatario abre chat (VISTO)
      SessionService.oir_chat("privado", user2.receptor_id, user1.receptor_id, ws2)
      :timer.sleep(300)

      assert_receive_websocket(ws1, {:estado_mensaje_actualizado, _, "VISTO"})

      mensajes = Mensajeria.obtener_mensajes_usuarios(user1.receptor_id, user2.receptor_id)
      mensaje = List.first(mensajes)
      assert mensaje.estado == "VISTO"
    end
  end
end
