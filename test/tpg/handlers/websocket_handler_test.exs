defmodule Tpg.Handlers.WebSocketHandlerTest do
  use Tpg.DataCase, async: false
  alias Tpg.Dominio.Receptores
  alias Tpg.WebSocketHandler
  alias Tpg.Dominio.Dto.WebSocket
  alias Tpg.Services.SessionService

  setup do
    req = %{qs: "usuario=usuario1&contrasenia=Contrasenia@1&operacion=crear"}
    {:cowboy_websocket, ^req, %WebSocket{} = state} = WebSocketHandler.init(req, %{})

    on_exit(fn -> WebSocketHandler.terminate(:normal, %{}, state) end)

    {:ok, usuario1} = Receptores.crear_usuario(%{nombre: "usuario1", contrasenia: "Contrasenia@1"})
    {:ok, usuario2} = Receptores.crear_usuario(%{nombre: "usuario2", contrasenia: "Contrasenia@2"})
    {:ok, _} = Receptores.agregar_contacto(usuario1.receptor_id, usuario2.nombre)

    {:ok, _} = Tpg.habilitar_canales(usuario1.receptor_id)
    {:ok, _} = Tpg.habilitar_canales(usuario2.receptor_id)

    {:ok,
     usuario1: usuario1,
     usuario2: usuario2}
  end

  test "init devuelve estado con parametros de query" do
    req = %{qs: "usuario=usuario2&contrasenia=Contrasenia@2&operacion=conectar"}

    assert {:cowboy_websocket, ^req, %WebSocket{} = state} =
             WebSocketHandler.init(req, %{})

    assert state.usuario == "usuario2"
    assert state.contrasenia == "Contrasenia@2"
    assert state.operacion == "conectar"

    WebSocketHandler.terminate(:normal, %{}, state)
  end

  test "Cerrar sesión de usuario desconectado" do
    state = %WebSocket{id: 9999, usuario: "usuario_desconocido", contrasenia: "Contrasenia@X", operacion: "conectar", server_pid: self()}

    assert :ok = WebSocketHandler.terminate(:normal, %{}, state)
  end

  test "websocket_init conecta sesion y responde bienvenida", %{usuario2: usuario2} do
    state = %WebSocket{usuario: usuario2.nombre, contrasenia: usuario2.contrasenia, operacion: "conectar"}

    assert {:reply, {:text, respuesta}, %WebSocket{} = new_state} =
             WebSocketHandler.websocket_init(state)

    assert new_state.id == usuario2.receptor_id
    assert new_state.contrasenia == usuario2.contrasenia
    assert {:ok, %{"tipo" => "bienvenida"}} = Jason.decode(respuesta)

    WebSocketHandler.terminate(:normal, %{}, new_state)
  end

  test "websocket_init registra sesion y responde bienvenida" do
    state = %WebSocket{usuario: "usuario3", contrasenia: "Contrasenia@3", operacion: "crear"}

    assert {:reply, {:text, respuesta}, %WebSocket{} = new_state} =
             WebSocketHandler.websocket_init(state)

    assert {:ok, %{"tipo" => "bienvenida"}} = Jason.decode(respuesta)

    WebSocketHandler.terminate(:normal, %{}, new_state)
  end

  test "Mensaje con acción desconocida devuelve error" do
    state = %WebSocket{}
    payload = Jason.encode!(%{"accion" => "desconocida", "foo" => "bar"})

    assert {:reply, {:text, respuesta}, ^state} =
             WebSocketHandler.websocket_handle({:text, payload}, state)

    assert {:ok, %{"tipo" => "error", "mensaje" => mensaje}} = Jason.decode(respuesta)
    assert String.contains?(mensaje, "Acción desconocida")
  end

  test "JSON inválido devuelve error" do
    state = %WebSocket{}

    assert {:reply, {:text, respuesta}, ^state} =
             WebSocketHandler.websocket_handle({:text, "{invalid"}, state)

    assert {:ok, %{"tipo" => "error", "mensaje" => "JSON inválido"}} = Jason.decode(respuesta)
  end

  test "websocket_handle ignora frames no text" do
    state = %WebSocket{}

    assert {:ok, ^state} = WebSocketHandler.websocket_handle(:ping, state)
  end

  test "websocket_info cerrar conexión detiene el socket" do
    state = %WebSocket{}

    assert {:stop, ^state} = WebSocketHandler.websocket_info(:cerrar_conexion, state)
  end

  test "websocket_info down devuelve mensaje de sistema" do
    state = %WebSocket{}

    assert {:reply, {:text, respuesta}, ^state} =
             WebSocketHandler.websocket_info({:DOWN, make_ref(), :process, self(), :normal}, state)

    assert {:ok, %{"tipo" => "sistema"}} = Jason.decode(respuesta)
  end

  test "websocket_info resultado de búsqueda y error" do
    state = %WebSocket{}

    assert {:reply, {:text, ok_resp}, ^state} =
             WebSocketHandler.websocket_info({:resultado_busqueda, {:mensajes_buscados, [%{contenido: "hola"}]}}, state)

    assert {:ok, %{"tipo" => "mensajes_buscados"}} = Jason.decode(ok_resp)

    assert {:reply, {:text, err_resp}, ^state} =
             WebSocketHandler.websocket_info({:resultado_busqueda, {:error, "fallo"}}, state)

    assert {:ok, %{"tipo" => "error"}} = Jason.decode(err_resp)
  end

  test "websocket_info notificación delega a handler" do
    state = %WebSocket{}
    payload = %{contacto: %{receptor_id: 1, nombre: "Usuario"}}

    assert {:reply, {:text, respuesta}, ^state} =
             WebSocketHandler.websocket_info({:notificacion, :contacto_en_linea, payload}, state)

    assert {:ok, %{"tipo" => "contacto_en_linea"}} = Jason.decode(respuesta)
  end

  test "websocket_info info desconocida no altera estado" do
    state = %WebSocket{}

    assert {:ok, ^state} = WebSocketHandler.websocket_info(:algo_desconocido, state)
  end

  test "websocket_info lista conversaciones y notificaciones", %{usuario1: usuario1} do
    state = %WebSocket{id: usuario1.receptor_id, usuario: usuario1.nombre}

    assert {:reply, {:text, resp_contactos}, ^state} =
             WebSocketHandler.websocket_info({:listar_conversaciones, usuario1.receptor_id}, state)

    assert {:ok, %{"tipo" => "contactos"}} = Jason.decode(resp_contactos)

    assert {:reply, {:text, resp_notifs}, ^state} =
             WebSocketHandler.websocket_info({:listar_notificaciones, usuario1.receptor_id}, state)

    assert {:ok, %{"tipo" => "notificaciones"}} = Jason.decode(resp_notifs)
  end

  test "websocket_handle buscar_mensajes envía resultado", %{usuario1: usuario1, usuario2: usuario2} do
    state = %WebSocket{id: usuario1.receptor_id, usuario: usuario1.nombre}

    payload =
      Jason.encode!(%{
        "accion" => "buscar_mensajes",
        "tipo" => "privado",
        "emisor" => usuario1.receptor_id,
        "destinatario" => usuario2.receptor_id,
        "query_text" => "hola"
      })

    assert {:ok, ^state} = WebSocketHandler.websocket_handle({:text, payload}, state)

    assert_receive {:resultado_busqueda, {:error, _}}, 1_000
  end

  test "websocket_handle enviar privado confirma", %{usuario1: usuario1, usuario2: usuario2} do
    state = %WebSocket{id: usuario1.receptor_id, usuario: usuario1.nombre}

    payload =
      Jason.encode!(%{
        "accion" => "enviar",
        "tipo" => "privado",
        "para" => usuario2.receptor_id,
        "mensaje" => "hola"
      })

    assert {:reply, {:text, respuesta}, ^state} =
             WebSocketHandler.websocket_handle({:text, payload}, state)

    assert {:ok, %{"tipo" => "sistema"}} = Jason.decode(respuesta)
  end

  test "websocket_handle abrir_chat responde chat_abierto", %{usuario1: usuario1, usuario2: usuario2} do
    state = %WebSocket{usuario: usuario1.nombre, contrasenia: usuario1.contrasenia, operacion: "conectar"}

    assert {:reply, {:text, _}, %WebSocket{} = new_state} =
             WebSocketHandler.websocket_init(state)

    on_exit(fn -> WebSocketHandler.terminate(:normal, %{}, new_state) end)

    payload =
      Jason.encode!(%{
        "accion" => "abrir_chat",
        "tipo" => "privado",
        "receptor_id" => usuario2.receptor_id
      })

    assert {:reply, {:text, respuesta}, ^new_state} =
             WebSocketHandler.websocket_handle({:text, payload}, new_state)

    assert {:ok, %{"tipo" => "chat_abierto"}} = Jason.decode(respuesta)
  end

  test "websocket_handle crear_grupo responde contacto_nuevo", %{usuario1: usuario1, usuario2: usuario2} do
    state = %WebSocket{id: usuario1.receptor_id, usuario: usuario1.nombre}

    payload =
      Jason.encode!(%{
        "accion" => "crear_grupo",
        "nombre" => "Grupo Test",
        "miembros" => [usuario2.receptor_id]
      })

    assert {:reply, {:text, respuesta}, ^state} =
             WebSocketHandler.websocket_handle({:text, payload}, state)

    assert {:ok, %{"tipo" => "contacto_nuevo"}} = Jason.decode(respuesta)
  end

  test "websocket_handle agregar_contacto responde sistema y contacto_nuevo", %{usuario1: usuario1} do
    {:ok, usuario3} = Receptores.crear_usuario(%{nombre: "usuario3", contrasenia: "Contrasenia@3"})
    state = %WebSocket{id: usuario1.receptor_id, usuario: usuario1.nombre}

    payload =
      Jason.encode!(%{
        "accion" => "agregar_contacto",
        "nombre_usuario" => usuario3.nombre
      })

    assert {:reply, frames, ^state} =
             WebSocketHandler.websocket_handle({:text, payload}, state)

    tipos =
      frames
      |> Enum.map(fn {:text, json} -> Jason.decode!(json)["tipo"] end)

    assert "sistema" in tipos
    assert "contacto_nuevo" in tipos
  end

  test "websocket_init con credenciales inválidas responde error" do
    state = %WebSocket{usuario: "no_existe", contrasenia: "mal", operacion: "conectar"}

    assert {:reply, {:text, respuesta}, %WebSocket{}} =
             WebSocketHandler.websocket_init(state)

    assert {:ok, %{"tipo" => "error"}} = Jason.decode(respuesta)
  end

  test "websocket_init cuando ya está conectado devuelve error", %{usuario1: usuario1} do
    assert {:ok, _} =
             SessionService.loggear(:conectar, %{nombre: usuario1.nombre, contrasenia: usuario1.contrasenia})

    on_exit(fn -> SessionService.desloggear(usuario1.receptor_id) end)

    state = %WebSocket{usuario: usuario1.nombre, contrasenia: usuario1.contrasenia, operacion: "conectar"}

    assert {:reply, {:text, respuesta}, %WebSocket{}} =
             WebSocketHandler.websocket_init(state)

    assert {:ok, %{"tipo" => "error"}} = Jason.decode(respuesta)
  end

  test "websocket_handle abrir_chat con receptor inválido provoca salida", %{usuario1: usuario1} do
    state = %WebSocket{usuario: usuario1.nombre, contrasenia: usuario1.contrasenia, operacion: "conectar"}

    assert {:reply, {:text, _}, %WebSocket{} = new_state} =
             WebSocketHandler.websocket_init(state)

    on_exit(fn -> WebSocketHandler.terminate(:normal, %{}, new_state) end)

    payload =
      Jason.encode!(%{
        "accion" => "abrir_chat",
        "tipo" => "privado",
        "receptor_id" => 999_999
      })

    assert catch_exit(
             WebSocketHandler.websocket_handle({:text, payload}, new_state)
           )
  end
end
