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

end
