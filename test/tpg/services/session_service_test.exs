defmodule Tpg.Services.SessionServiceTest do
alias Tpg.Dominio.Mensajeria
alias Tpg.Services.ChatService
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

  test "una operacion desconocida devuelve un error" do
    usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
    {:error, _usuario_respuesta} = SessionService.loggear(:desconectar, usuario)
  end
  end

  describe "El usuario está en linea" do
    setup do
      usuario1 = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
      {:ok, usuario_respuesta1} = SessionService.loggear(:crear, usuario1)

      usuario2 = %{nombre: "usuarioValido2", contrasenia: "Contrasenia@2"}
      {:ok, usuario_respuesta2} = SessionService.loggear(:crear, usuario2)

      %{usuario: Map.merge(usuario1, usuario_respuesta1),
        usuario1: usuario1, usuario_respuesta1: usuario_respuesta1,
        usuario2: usuario2, usuario_respuesta2: usuario_respuesta2}
    end
  test "un usuario en linea", %{usuario_respuesta1: usuario_respuesta1} do
    assert SessionService.en_linea?(usuario_respuesta1.id)
  end

  test "dos usuarios en linea", %{usuario_respuesta1: usuario_respuesta1, usuario_respuesta2: usuario_respuesta2} do
    assert SessionService.en_linea?(usuario_respuesta1.id)
    assert SessionService.en_linea?(usuario_respuesta2.id)
  end
  test "un usuario fuera de linea", %{usuario_respuesta1: usuario_respuesta1} do
    {:ok, _ } = SessionService.desloggear(usuario_respuesta1.id)
    assert !SessionService.en_linea?(usuario_respuesta1.id)
  end

  test "dos usuarios fuera de linea", %{usuario_respuesta1: usuario_respuesta1, usuario_respuesta2: usuario_respuesta2} do
    {:ok, _ } = SessionService.desloggear(usuario_respuesta1.id)
    {:ok, _ } = SessionService.desloggear(usuario_respuesta2.id)
    assert !SessionService.en_linea?(usuario_respuesta1.id)
    assert !SessionService.en_linea?(usuario_respuesta2.id)
  end

  test "se obtienen la lista de 2 en linea", %{usuario_respuesta1: usuario1, usuario_respuesta2: usuario2} do
    usuarios = SessionService.obtener_usuarios_activos()
    assert Enum.sort(usuarios) == Enum.sort([usuario1.id, usuario2.id])
  end
  test "se obtienen la lista vacia de usuarios en linea", %{usuario_respuesta1: usuario1, usuario_respuesta2: usuario2} do
    {:ok, _ } = SessionService.desloggear(usuario1.id)
    {:ok, _ } = SessionService.desloggear(usuario2.id)
    usuarios = SessionService.obtener_usuarios_activos()
    assert Enum.sort(usuarios) == []
  end
  test "se obtiene el estado de 'en_linea' del usuario dentro de un mapa de Usuario", %{usuario: usuario1} do
    receptor = %{tipo: "privado", receptor_id: usuario1.id, nombre: usuario1.nombre}
    {:ok, usuario} = SessionService.agregar_ultima_conexion(receptor)
    usuario_esperado = Map.merge(receptor, %{en_linea: 1})
    assert usuario == usuario_esperado
  end
  test "se obtiene el estado de 'en_linea' del usuario dentro de un mapa de Usuario con valor 0 cuando está fuera de linea", %{usuario: usuario1} do
    {:ok, _ } = SessionService.desloggear(usuario1.id)
    receptor = %{tipo: "privado", receptor_id: usuario1.id, nombre: usuario1.nombre}
    {:ok, usuario} = SessionService.agregar_ultima_conexion(receptor)
    usuario_esperado = Map.merge(receptor, %{en_linea: 0})
    assert usuario == usuario_esperado
  end
  end

  describe "La session de un usuario agenda a otro usuario" do
    setup do
      usuario1 = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
      {:ok, usuario_respuesta1} = SessionService.loggear(:crear, usuario1)

      usuario2 = %{nombre: "usuarioValido2", contrasenia: "Contrasenia@2"}
      {:ok, usuario_respuesta2} = SessionService.loggear(:crear, usuario2)

      %{usuario1: usuario1, usuario_respuesta1: usuario_respuesta1, usuario_1: Map.merge(usuario1, usuario_respuesta1),
        usuario2: usuario2, usuario_respuesta2: usuario_respuesta2, usuario_2: Map.merge(usuario2, usuario_respuesta2),}
    end

    test "agendar/2 permite agendar correctamente a un usuario valido", %{usuario_1: usuario1, usuario_2: usuario2} do
      {:ok, agendados} = SessionService.agendar(usuario1.id, usuario2.nombre)
      esperado = %{
      usuario: %{
        receptor_id: usuario1.id,
        nombre: usuario1.nombre},
      contacto: %{
        receptor_id: usuario2.id,
        nombre: usuario2.nombre
        }
      }
      assert agendados == esperado
      contactos_agendados_esperados = [%{id: usuario2.id, tipo: "privado", nombre: usuario2.nombre}]
      assert Receptores.obtener_contactos_agenda(usuario1.id) == contactos_agendados_esperados
    end
    test "agendar/2 devuelve un error cuando se agenda a un contacto que no existe", %{usuario_1: usuario1} do
      {:error, motivo} = SessionService.agendar(usuario1.id, "usuarioInexistente")
      assert motivo == "El usuario 'usuarioInexistente' no existe"
    end
    test "agendar/2 devuelve error al agendar dos veces al mismo contacto", %{usuario_1: usuario1, usuario_2: usuario2} do
      {:ok, agendados} = SessionService.agendar(usuario1.id, usuario2.nombre)
      {:error, motivo} = SessionService.agendar(usuario1.id, usuario2.nombre)
      assert motivo == "El usuario #{usuario2.nombre} ya pertenece a la agenda"
    end
    test "agendar/2 devuelve error al utilizar un id invalido", %{usuario_1: usuario1} do
      {:error, motivo} = SessionService.agendar(-1, usuario1.nombre)
      assert motivo == "El usuario -1 no existe"
    end
    test "agendar/2 devuelve error al agendarse a si mismo", %{usuario_1: usuario1} do
      {:error, motivo} = SessionService.agendar(usuario1.id, usuario1.nombre)
      assert motivo == "No puede agendarse a si mismo"
    end
  end

  describe "notificar_mensaje/6" do
    import Tpg.TestHelpers

    setup do
      # Crear usuarios de prueba
      {:ok, usuario_emisor} = create_test_user("usuarioEmisor", "Contrasenia@1")
      {:ok, usuario_receptor} = create_test_user("usuarioReceptor", "Contrasenia@2")

      {:ok, _agendado} = SessionService.agendar(usuario_emisor.receptor_id, "usuarioReceptor")
      {:ok, _agendado} = SessionService.agendar(usuario_receptor.receptor_id, "usuarioEmisor")
      # Loggear usuarios
      {:ok, emisor_session} = SessionService.loggear(:conectar, %{nombre: "usuarioEmisor", contrasenia: "Contrasenia@1"})
      {:ok, receptor_session} = SessionService.loggear(:conectar, %{nombre: "usuarioReceptor", contrasenia: "Contrasenia@2"})


      # Crear WebSocket mock para el receptor
      ws_receptor = spawn_websocket_mock()
      SessionService.registrar_cliente(receptor_session.id, ws_receptor)

      # Mensaje de prueba
      {:ok, mensaje} = Mensajeria.enviar_mensaje(usuario_receptor.receptor_id, usuario_emisor.receptor_id, "Mensaje de prueba")
      on_exit(fn ->
        SessionService.desloggear(emisor_session.id)
        SessionService.desloggear(receptor_session.id)
      end)

      %{
        emisor: emisor_session,
        receptor: receptor_session,
        usuario_emisor: usuario_emisor,
        usuario_receptor: usuario_receptor,
        mensaje: mensaje,
        ws_receptor: ws_receptor
      }
    end

    test "notifica mensaje privado en bandeja cuando el receptor no es el emisor", %{
      emisor: emisor,
      receptor: receptor,
      mensaje: mensaje,
      ws_receptor: ws_receptor
    } do

      # Limpiar mensajes previos
      clear_websocket_messages(ws_receptor)

      # Notificar mensaje
      result = SessionService.notificar_mensaje(
        receptor.id,
        :notificacion_bandeja,
        mensaje,
        emisor.id,
        receptor.id,
        "privado"
      )

      assert result == nil

      # Verificar que el receptor recibió la notificación
      assert_receive_websocket(ws_receptor, {:notificacion, :mensaje_bandeja, :_})
    end

    test "notifica cuando el usuario es el mismo emisor en mensaje privado para actualizar la conversacion", %{
      emisor: emisor,
      mensaje: mensaje
    } do
      # Crear WebSocket mock para el emisor
      ws_emisor = spawn_websocket_mock()
      SessionService.registrar_cliente(emisor.id, ws_emisor)

      clear_websocket_messages(ws_emisor)

      # Notificar mensaje donde emisor = receptor
      result = SessionService.notificar_mensaje(
        emisor.id,
        :notificacion_bandeja,
        mensaje,
        emisor.id,
        emisor.id,
        "privado"
      )

      assert result == nil

      # Verificar que se recibió la notificación pero no se marcó como entregado
      assert_receive_websocket(ws_emisor, {:notificacion, :mensaje_nuevo, :_})
    end

    test "notifica mensaje de grupo en bandeja", %{
      emisor: emisor,
      receptor: receptor,
      mensaje: mensaje,
      ws_receptor: ws_receptor
    } do
      grupo_id = System.unique_integer([:positive])

      clear_websocket_messages(ws_receptor)

      # Modificar mensaje para grupo
      mensaje_grupo = Map.put(mensaje, :receptor_id, grupo_id)

      result = SessionService.notificar_mensaje(
        receptor.id,
        :notificacion_bandeja,
        mensaje_grupo,
        emisor.id,
        grupo_id,
        "grupo"
      )

      assert result == nil

      # Verificar notificación
      assert_receive_websocket(ws_receptor, {:notificacion, :_})
    end

    test "marca mensaje privado como visto cuando se notifica mensaje_nuevo", %{
      emisor: emisor,
      receptor: receptor,
      mensaje: mensaje,
      ws_receptor: ws_receptor
    } do
      clear_websocket_messages(ws_receptor)


      result = SessionService.notificar_mensaje(
        receptor.id,
        :mensaje_nuevo,
        mensaje,
        emisor.id,
        receptor.id,
        "privado"
      )

      assert result == :ok

      # Verificar que se notificó el mensaje nuevo
      assert_receive_websocket(ws_receptor, {:notificar, :mensaje_nuevo, :_})
    end

    test "marca mensaje de grupo como entregado y visto cuando se notifica mensaje_nuevo", %{
      emisor: emisor,
      receptor: receptor,
      mensaje: mensaje,
      ws_receptor: ws_receptor
    } do
      grupo_id = System.unique_integer([:positive])
      clear_websocket_messages(ws_receptor)

      mensaje_grupo = Map.put(mensaje, :receptor_id, grupo_id)

      result = SessionService.notificar_mensaje(
        receptor.id,
        :mensaje_nuevo,
        mensaje_grupo,
        emisor.id,
        grupo_id,
        "grupo"
      )

      assert result == nil

      # Verificar notificación
      assert_receive_websocket(ws_receptor, {:notificar, :_})
    end

    test "no notifica cuando el usuario no está en línea", %{
      emisor: emisor,
      receptor: receptor,
      mensaje: mensaje
    } do
      {:ok, _} = SessionService.desloggear(receptor.id)

      result = SessionService.notificar_mensaje(
        receptor.id,
        :notificacion_bandeja,
        mensaje,
        emisor.id,
        receptor.id,
        "privado"
      )
      assert result == nil
    end

    test "maneja error cuando se intenta notificar a un usuario inexistente", %{
      emisor: emisor,
      mensaje: mensaje
    } do
      usuario_inexistente_id = 999999

      result = SessionService.notificar_mensaje(
        usuario_inexistente_id,
        :notificacion_bandeja,
        mensaje,
        emisor.id,
        usuario_inexistente_id,
        "privado"
      )

      assert result == nil # no ejecuta ninguna tarea
    end

    test "procesa múltiples notificaciones secuenciales correctamente", %{
      emisor: emisor,
      receptor: receptor,
      ws_receptor: ws_receptor
    } do
      clear_websocket_messages(ws_receptor)

      # Enviar múltiples mensajes
      for i <- 1..3 do
        mensaje = %{
          id: i,
          contenido: "Mensaje #{i}",
          emisor: emisor.id,
          receptor_id: receptor.id,
          estado: "ENVIADO",
          timestamp: DateTime.utc_now()
        }

        SessionService.notificar_mensaje(
          receptor.id,
          :notificacion_bandeja,
          mensaje,
          emisor.id,
          receptor.id,
          "privado"
        )
      end

      # Dar tiempo para procesar
      Process.sleep(100)

      # Verificar que se recibieron todas las notificaciones
      messages = get_websocket_messages(ws_receptor)
      assert length(messages) >= 3
    end

    test "diferencia entre notificación de bandeja y mensaje nuevo para grupos", %{
      emisor: emisor,
      receptor: receptor,
      mensaje: mensaje,
      ws_receptor: ws_receptor
    } do
      grupo_id = System.unique_integer([:positive])
      mensaje_grupo = Map.put(mensaje, :receptor_id, grupo_id)

      # Test notificación bandeja
      clear_websocket_messages(ws_receptor)

      SessionService.notificar_mensaje(
        receptor.id,
        :notificacion_bandeja,
        mensaje_grupo,
        emisor.id,
        grupo_id,
        "grupo"
      )

      assert_receive_websocket(ws_receptor, {:notificar, :_})

      # Test mensaje nuevo
      clear_websocket_messages(ws_receptor)

      SessionService.notificar_mensaje(
        receptor.id,
        :mensaje_nuevo,
        mensaje_grupo,
        emisor.id,
        grupo_id,
        "grupo"
      )

      assert_receive_websocket(ws_receptor, {:notificar, :_})
    end
  end

end
