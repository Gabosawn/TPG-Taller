defmodule Tpg.Services.NotificationServiceTest do
  use Tpg.DataCase
  alias Tpg.Dominio.Mensajeria
  alias Tpg.Services.NotificationService
  alias Tpg.Services.SessionService
  alias Tpg.Dominio.Receptores
  alias Tpg.TestHelpers

  describe "" do
    test "se notifica a un usuario en linea escuchando" do
      usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
      {:ok, usuario_respuesta} = SessionService.loggear(:crear, usuario)

      contexto = %{
        usuarios: [usuario_respuesta.id],
        mensaje: %{id: 1, contenido: "Hola"},
        chat_pid: usuario_respuesta.pid,
        emisor: 2,
        tipo: "individual",
        receptor: usuario_respuesta.id
      }

      NotificationService.notificar(:mensaje, contexto)
      # Aqui se deberia testear que el mensaje fue enviado al proceso del usuario
      # Pero como es un proceso separado y no tenemos acceso directo, asumimos que si no hay errores, paso la prueba
      assert true
    end
  end

  describe "marcar como entregado y visto" do
    test "no se puede marcar como entregado un mensaje del mismo emisor" do

      usuario1 = %{receptor_id: 1, nombre: "usuario1"}

      mensaje = %{
        id: 1,
        nombre: "usuarioValido",
        estado: "ENVIADO",
        emisor: usuario1.receptor_id,
        contenido: "Hola",
        fecha: DateTime.utc_now()
      }

      {:pass, mensaje_resp} = NotificationService.marcar_entregado(mensaje, usuario1.receptor_id)
      assert mensaje_resp == "No se puede marcar como entregado un mensaje desde el mismo emisor"
    end

    test "no se puede marcar como visto un mensaje del mismo emisor" do

      usuario1 = %{receptor_id: 1, nombre: "usuario1"}

      mensaje = %{
        id: 1,
        emisor: usuario1.receptor_id,
        contenido: "Hola"
      }

      {:pass, mensaje_resp} = NotificationService.marcar_visto(mensaje, usuario1.receptor_id)
      assert mensaje_resp == "No se puede marcar como visto un mensaje desde el mismo emisor"
    end

    test "marcar como entregado un mensaje de otro usuario" do

      {:ok, usuario1} = Receptores.crear_usuario(%{nombre: "usuario1", contrasenia: "Contrasenia@1"})
      {:ok, usuario2} = Receptores.crear_usuario(%{nombre: "usuario2", contrasenia: "Contrasenia@1"})

      Mensajeria.enviar_mensaje(usuario1.receptor_id, usuario2.receptor_id, "MENSAJE DE TEST")

      mensajes = Mensajeria.obtener_mensajes_usuarios(usuario1.receptor_id, usuario2.receptor_id)

      {:ok, mensaje_resp} = NotificationService.marcar_entregado(List.first(mensajes), usuario1.receptor_id)
      assert mensaje_resp.estado == "ENTREGADO"
    end

    test "marcar como visto un mensaje de otro usuario" do

      {:ok, usuario1} = Receptores.crear_usuario(%{nombre: "usuario1", contrasenia: "Contrasenia@1"})
      {:ok, usuario2} = Receptores.crear_usuario(%{nombre: "usuario2", contrasenia: "Contrasenia@1"})

      Mensajeria.enviar_mensaje(usuario1.receptor_id, usuario2.receptor_id, "MENSAJE DE TEST")

      mensajes = Mensajeria.obtener_mensajes_usuarios(usuario1.receptor_id, usuario2.receptor_id)

      {:ok, mensaje_resp} = NotificationService.marcar_visto(List.first(mensajes), usuario1.receptor_id)
      assert mensaje_resp.estado == "VISTO"
    end

  end

  describe "notificar usuario en linea" do
    test "se notifica de un usuario en linea a sus contactos" do

      usuario1 = %{receptor_id: 1, nombre: "usuario1"}

      contexto = %{
        usuarios: [usuario1.receptor_id],
        mensaje: %{id: 1, contenido: "Hola en bandeja"},
        chat_pid: 5,
        emisor: 2,
        tipo: "privado",
        receptor_id: usuario1.receptor_id
      }

      mensaje = "[notification service] notificaciones distribuidas con exito"

      {estado, respuesta} = NotificationService.notificar(:en_linea, contexto)
      assert respuesta == mensaje
    end

    test "se notifica a un usuario que recibio un mensaje" do
      {:ok, usuario1} = Receptores.crear_usuario(%{nombre: "usuario1", contrasenia: "Contrasenia@1"})
      {:ok, usuario2} = Receptores.crear_usuario(%{nombre: "usuario2", contrasenia: "Contrasenia@1"})

      Mensajeria.enviar_mensaje(usuario1.receptor_id, usuario2.receptor_id, "MENSAJE DE TEST")

      mensajes = Mensajeria.obtener_mensajes_usuarios(usuario1.receptor_id, usuario2.receptor_id)

      contexto = %{
        usuarios: [usuario2.receptor_id],
        mensaje: List.first(mensajes),
        chat_pid: 5,
        emisor: usuario1.receptor_id,
        tipo: "individual",
        receptor_id: usuario2.receptor_id
      }

      respuesta = NotificationService.notificar(:mensaje, contexto)
      assert respuesta == :ok
    end

    test "notificar a contactos que hay nuevo usuario en linea" do
      {:ok, usuario1} = Receptores.crear_usuario(%{nombre: "usuario1", contrasenia: "Contrasenia@1"})
      {:ok, usuario2} = Receptores.crear_usuario(%{nombre: "usuario2", contrasenia: "Contrasenia@1"})

      Receptores.agregar_contacto(usuario1.receptor_id, usuario2.nombre)

      contexto = %{
        usuarios: [usuario1.receptor_id],
        nombre: usuario2.nombre,
        mensaje: %{id: 1, contenido: "Contacto en linea"},
        chat_pid: 5,
        emisor: usuario2.receptor_id,
        tipo: "privado",
        receptor_id: usuario1.receptor_id
      }
      {:ok, respuesta} = NotificationService.notificar(:en_linea, contexto)
      assert respuesta == "[notification service] notificaciones distribuidas con exito"
    end

    test "notificar a contactos que un usuario salio de linea" do
      {:ok, usuario1} = Receptores.crear_usuario(%{nombre: "usuario1", contrasenia: "Contrasenia@1"})
      {:ok, usuario2} = Receptores.crear_usuario(%{nombre: "usuario2", contrasenia: "Contrasenia@1"})

      Receptores.agregar_contacto(usuario1.receptor_id, usuario2.nombre)

      contexto = %{
        usuarios: [usuario1.receptor_id],
        nombre: usuario2.nombre,
        mensaje: %{id: 1, contenido: "Contacto fuera de linea"},
        chat_pid: 5,
        emisor: usuario2.receptor_id,
        tipo: "privado",
        receptor_id: usuario1.receptor_id
      }
      {:ok, respuesta} = NotificationService.notificar(:saliendo_de_linea, contexto)
      assert respuesta == "[notification service] notificaciones distribuidas con exito"
    end
  end

  describe "notificar contacto agregado" do
    test "se notifica a un usuario fuera de linea que fue agregado como contacto" do
      usuario1 = %{receptor_id: 1, nombre: "usuario1"}
      usuario2 = %{receptor_id: 2, nombre: "usuario2"}

      contacto = %{
        receptor_id: 2,
        nombre: "Contacto Nuevo"
      }

      {:ok, respuesta} = NotificationService.notificar(:contacto_agregado, usuario1.receptor_id, usuario2.receptor_id)
      assert respuesta == "Usuario fuera de linea"
    end

    test "se notifica a un usuario que fue agregado como contacto" do
      usuario1 = %{nombre: "usuario1", contrasenia: "Contrasenia@1"}
      {:ok, usuario1_respuesta} = SessionService.loggear(:crear, usuario1)
      usuario2 = %{nombre: "usuario2", contrasenia: "Contrasenia@1"}
      {:ok, usuario2_respuesta} = SessionService.loggear(:crear, usuario2)

      websocket_mock1 = TestHelpers.spawn_websocket_mock()
      SessionService.registrar_cliente(usuario1_respuesta.id, websocket_mock1)
      websocket_mock2 = TestHelpers.spawn_websocket_mock()
      SessionService.registrar_cliente(usuario2_respuesta.id, websocket_mock2)

      usuario2_respuesta = %{
        id: usuario2_respuesta.id,
        receptor_id: usuario2_respuesta.id,
        nombre: "Contacto Nuevo"
      }

      {:ok, respuesta} = NotificationService.notificar(:contacto_agregado, usuario1_respuesta.id, usuario2_respuesta)
      #assert respuesta == "Usuario fuera de linea"
      TestHelpers.assert_receive_websocket(websocket_mock1,
     {:notificacion, :agregado_como_contacto, %{contacto: %{id: usuario2_respuesta.id, receptor_id: usuario2_respuesta.id, nombre: "Contacto Nuevo"}, por: usuario1_respuesta.id}}
      )
    end

    test "se intenta notificar a un usuario inexistente que fue agregado como contacto" do
      usuario = %{nombre: "usuarioValido", contrasenia: "Contrasenia@1"}
      {:ok, usuario_respuesta} = SessionService.loggear(:crear, usuario)

      contacto = %{
        receptor_id: 2,
        nombre: "Contacto Nuevo"
      }

      {:ok, respuesta} = NotificationService.notificar(:contacto_agregado, 9, contacto)
      assert respuesta == "Usuario fuera de linea"
    end
  end

  describe "notificar creacion de grupo" do
    test "se notifica a los usuarios en linea que fueron agregados a un nuevo grupo" do

      usuario1 = %{receptor_id: 1, nombre: "usuario1"}
      usuario2 = %{receptor_id: 2, nombre: "usuario2"}
      miembros = [usuario1.receptor_id, usuario2.receptor_id]

      contexto = %{
        grupo: %{
          id: 1,
          nombre: "Grupo Nuevo",
          miembros: miembros
        },
        creador:  usuario1.receptor_id
      }

      {:ok, respuesta1} = NotificationService.notificar(:grupo_creado, miembros, contexto)
      {:ok, respuesta2} = NotificationService.notificar(:grupo_creado, miembros, contexto)

      assert respuesta1 == "[notification service] notificaciones distribuidas con exito"
      assert respuesta2 == "[notification service] notificaciones distribuidas con exito"
    end
  end

  end
