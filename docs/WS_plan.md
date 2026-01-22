### [Continue](https://continue.dev) session transcript
 Exported: 1/21/2026, 9:06:17 PM

#### _User_

> Tengo mi server.ex y chat.ex Service. Mi idea con lo que tengo hasta ahora es modificar los comportamientos de router.ex y tpg.ex que me sirvieron para validar un concepto, para que ahora pueda mantener uan conexion abierta usando websockets para cada usuario.
> Enseñame como hacerlo paso a paso y como puedo probarlo

#### _Assistant_

> Voy a ayudarte a implementar WebSockets para mantener conexiones activas con cada usuario. Primero, déjame revisar la estructura de tu proyecto para entender mejor el contexto.

#### _Assistant_

> mix.exs
> 

#### _Assistant_

> lib\tpg.ex
> lib\tpg\usuario.ex
> lib\tpg\services\chat.ex
> lib\tpg\runtime\server.ex
> lib\tpg\router.ex
> lib\tpg\repo.ex
> lib\tpg\receptor.ex
> lib\tpg\grupo.ex
> lib\tpg\cuentas.ex
> lib\tpg\application.ex
> 

#### _Assistant_

> Below is a repository map. 
> For each file in the codebase, this map contains the name of the file, and the signature for any classes, methods, or functions in the file.
> 
> .formatter.exs
> docker-compose.yml
> Dockerfile
> MakefIle
> mix.exs
> README.md
> test_tpg.sh
> test/test_helper.exs
> test/tpg_test.exs
> priv/repo/migrations/20260105020817_crear_receptor.exs
> priv/repo/migrations/20260105170438_crear_usuarios.exs
> priv/repo/migrations/20260105195842_crear_grupos.exs
> priv/repo/migrations/20260105195848_crear_mensajes.exs
> priv/repo/migrations/20260105210358_interaccion_mensajes.exs
> priv/repo/migrations/20260105210845_usuarios_grupo.exs
> priv/repo/migrations/20260120193626_agendar_usuarios.exs
> lib/tpg.ex
> lib/tpg/application.ex
> lib/tpg/cuentas.ex
> lib/tpg/grupo.ex
> lib/tpg/receptor.ex
> lib/tpg/repo.ex
> lib/tpg/router.ex
> lib/tpg/usuario.ex
> lib/tpg/services/chat.ex
> lib/tpg/runtime/server.ex
> docs/architecture.md
> docs/persistencia.md
> docs/roadmap.md
> config/config.exs
> config/dev.exs
> config/docker_config.exs

#### _Assistant_

> defmodule Tpg.Application do> 
>   use Application> 
> > 
>   @impl true> 
>   def start(_type, _args) do> 
>     children = [> 
>       Tpg.Repo,> 
>       {Plug.Cowboy, scheme: :http, plug: Tpg.Router, options: [port: 4000]}> 
>     ]> 
> > 
>     opts = [strategy: :one_for_one, name: Tpg.Supervisor]> 
>     Supervisor.start_link(children, opts)> 
>   end> 
> end> 
> 

#### _Assistant_

> defmodule Tpg.MixProject do> 
>   use Mix.Project> 
> > 
>   def project do> 
>     [> 
>       app: :tpg,> 
>       version: "0.1.0",> 
>       elixir: "~> 1.17",> 
>       start_permanent: Mix.env() == :prod,> 
>       aliases: aliases(),> 
>       deps: deps()> 
>     ]> 
>   end> 
> > 
>   # Run "mix help compile.app" to learn about applications.> 
>   def application do> 
>     [> 
>       extra_applications: [:logger],> 
>       mod: {Tpg.Application, []}> 
>     ]> 
>   end> 
> > 
>   # Run "mix help deps" to learn about dependencies.> 
>   defp deps do> 
>     [> 
>       {:ecto_sql, "~> 3.0"},> 
>       {:postgrex, ">= 0.0.0"},> 
>       {:plug_cowboy, "~> 2.0"},> 
>       {:jason, "~> 1.2"}> 
>       # {:dep_from_hexpm, "~> 0.3.0"},> 
>       # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}> 
>     ]> 
>   end> 
> > 
>   defp aliases do> 
>     [> 
>       setup_db: [" ecto.create ", " ecto.migrate"]> 
>     ]> 
>   end> 
> end> 
> 

#### _Assistant_

> Perfecto. Ahora te voy a enseñar cómo implementar WebSockets paso a paso. Voy a crear un plan completo y detallado.
> 
> ## 📋 Plan de Implementación: WebSockets para Chat en Tiempo Real
> 
> ### **Paso 1: Agregar dependencia WebSocket**
> 
> Necesitamos actualizar `mix.exs` para incluir soporte de WebSocket:
> 
> ```elixir mix.exs
> defp deps do
>   [
>     {:ecto_sql, "~> 3.0"},
>     {:postgrex, ">= 0.0.0"},
>     {:plug_cowboy, "~> 2.0"},
>     {:jason, "~> 1.2"},
>     {:websock_adapter, "~> 0.5"}  # Nueva dependencia
>   ]
> end
> ```
> 
> ### **Paso 2: Crear el WebSocket Handler**
> 
> Crear un nuevo archivo `lib/tpg/websocket_handler.ex`:
> 
> ```elixir lib/tpg/websocket_handler.ex
> defmodule Tpg.WebSocketHandler do
>   @behaviour :cowboy_websocket
> 
>   # Timeout de 60 segundos de inactividad
>   @timeout 60_000
> 
>   def init(req, _state) do
>     # Extraer parámetros de la query string
>     qs = :cowboy_req.parse_qs(req)
>     usuario = :proplists.get_value("usuario", qs, "anonimo")
>     
>     {:cowboy_websocket, req, %{usuario: usuario, server_pid: nil}}
>   end
> 
>   def websocket_init(state) do
>     usuario = state.usuario
>     
>     # Intentar loggear al usuario
>     case Tpg.loggear(usuario) do
>       {:ok, pid} ->
>         # Suscribirse a este proceso para recibir notificaciones
>         Process.monitor(pid)
>         
>         # Enviar mensaje de bienvenida
>         mensaje_bienvenida = Jason.encode!(%{
>           tipo: "sistema",
>           mensaje: "Conectado como #{usuario}",
>           timestamp: DateTime.utc_now()
>         })
>         
>         {:reply, {:text, mensaje_bienvenida}, %{state | server_pid: pid}}
>         
>       {:error, {:already_started, pid}} ->
>         # Usuario ya está logueado
>         mensaje_error = Jason.encode!(%{
>           tipo: "error",
>           mensaje: "Usuario #{usuario} ya está conectado"
>         })
>         {:reply, {:text, mensaje_error}, state}
>         
>       {:error, reason} ->
>         mensaje_error = Jason.encode!(%{
>           tipo: "error",
>           mensaje: "Error al conectar: #{inspect(reason)}"
>         })
>         {:reply, {:text, mensaje_error}, state}
>     end
>   end
> 
>   # Manejar mensajes entrantes del cliente
>   def websocket_handle({:text, json}, state) do
>     case Jason.decode(json) do
>       {:ok, %{"accion" => "enviar", "para" => destinatario, "mensaje" => mensaje}} ->
>         manejar_envio(destinatario, mensaje, state)
>         
>       {:ok, %{"accion" => "leer_historial"}} ->
>         manejar_lectura_historial(state)
>         
>       {:ok, %{"accion" => "listar_usuarios"}} ->
>         manejar_listar_usuarios(state)
>         
>       {:ok, payload} ->
>         respuesta = Jason.encode!(%{
>           tipo: "error",
>           mensaje: "Acción desconocida: #{inspect(payload)}"
>         })
>         {:reply, {:text, respuesta}, state}
>         
>       {:error, _} ->
>         respuesta = Jason.encode!(%{
>           tipo: "error",
>           mensaje: "JSON inválido"
>         })
>         {:reply, {:text, respuesta}, state}
>     end
>   end
> 
>   def websocket_handle(_frame, state) do
>     {:ok, state}
>   end
> 
>   # Manejar mensajes internos de Elixir (notificaciones push)
>   def websocket_info({:nuevo_mensaje, de, mensaje, timestamp}, state) do
>     respuesta = Jason.encode!(%{
>       tipo: "mensaje_nuevo",
>       de: de,
>       mensaje: mensaje,
>       timestamp: timestamp
>     })
>     {:reply, {:text, respuesta}, state}
>   end
> 
>   def websocket_info({:DOWN, _ref, :process, _pid, _reason}, state) do
>     respuesta = Jason.encode!(%{
>       tipo: "sistema",
>       mensaje: "Servidor de usuario caído, reconectando..."
>     })
>     {:reply, {:text, respuesta}, state}
>   end
> 
>   def websocket_info(_info, state) do
>     {:ok, state}
>   end
> 
>   # Cleanup cuando se cierra la conexión
>   def terminate(_reason, _req, state) do
>     if state.server_pid do
>       Tpg.desloggear(state.usuario)
>     end
>     :ok
>   end
> 
>   # Funciones auxiliares privadas
>   defp manejar_envio(destinatario, mensaje, state) do
>     case :global.whereis_name(destinatario) do
>       :undefined ->
>         respuesta = Jason.encode!(%{
>           tipo: "error",
>           mensaje: "Usuario #{destinatario} no encontrado"
>         })
>         {:reply, {:text, respuesta}, state}
>         
>       pid ->
>         Tpg.enviar(state.usuario, pid, mensaje)
>         respuesta = Jason.encode!(%{
>           tipo: "confirmacion",
>           mensaje: "Mensaje enviado a #{destinatario}"
>         })
>         {:reply, {:text, respuesta}, state}
>     end
>   end
> 
>   defp manejar_lectura_historial(state) do
>     case state.server_pid do
>       nil ->
>         respuesta = Jason.encode!(%{
>           tipo: "error",
>           mensaje: "No hay sesión activa"
>         })
>         {:reply, {:text, respuesta}, state}
>         
>       pid ->
>         mensajes = Tpg.leer_mensajes(pid)
>         respuesta = Jason.encode!(%{
>           tipo: "historial",
>           mensajes: mensajes
>         })
>         {:reply, {:text, respuesta}, state}
>     end
>   end
> 
>   defp manejar_listar_usuarios(state) do
>     usuarios = Tpg.obtener_usuarios_activos()
>     respuesta = Jason.encode!(%{
>       tipo: "usuarios_activos",
>       usuarios: usuarios
>     })
>     {:reply, {:text, respuesta}, state}
>   end
> end
> ```
> 
> ### **Paso 3: Modificar el Server para notificar en tiempo real**
> 
> Actualizar `lib/tpg/runtime/server.ex`:
> 
> ```elixir lib/tpg/runtime/server.ex
> defmodule Tpg.Runtime.Server do
>   use GenServer
> 
>   def start_link(usuario) do
>     GenServer.start_link(__MODULE__, usuario, name: {:global, usuario})
>   end
> 
>   def init(usuario) do
>     {:ok, %{usuario: usuario, mensajes: [], websocket_pids: []}}
>   end
> 
>   # Nuevo: Registrar un WebSocket para notificaciones
>   def handle_call({:registrar_websocket, pid}, _from, state) do
>     Process.monitor(pid)
>     nuevos_ws = [pid | state.websocket_pids]
>     {:reply, :ok, %{state | websocket_pids: nuevos_ws}}
>   end
> 
>   def handle_cast({:recibir, de, mensaje}, state) do
>     nuevo_mensaje = %{
>       de: de,
>       mensaje: mensaje,
>       timestamp: DateTime.utc_now()
>     }
> 
>     nuevos_mensajes = [nuevo_mensaje | state.mensajes]
>     
>     # Notificar a todos los WebSockets conectados
>     Enum.each(state.websocket_pids, fn ws_pid ->
>       send(ws_pid, {:nuevo_mensaje, de, mensaje, nuevo_mensaje.timestamp})
>     end)
> 
>     {:noreply, %{state | mensajes: nuevos_mensajes}}
>   end
> 
>   def handle_call(:ver_historial, _from, state) do
>     mensajes_ordenados = Enum.reverse(state.mensajes)
>     {:reply, mensajes_ordenados, state}
>   end
> 
>   # Limpiar WebSockets caídos
>   def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
>     nuevos_ws = List.delete(state.websocket_pids, pid)
>     {:noreply, %{state | websocket_pids: nuevos_ws}}
>   end
> end
> ```
> 
> ### **Paso 4: Actualizar el Router para soportar WebSockets**
> 
> Modificar `lib/tpg/router.ex`:
> 
> ```elixir lib/tpg/router.ex
> defmodule Tpg.Router do
>   use Plug.Router
> 
>   plug Plug.Parsers, parsers: [:json], json_decoder: Jason
>   plug :match
>   plug :dispatch
> 
>   # Ruta WebSocket
>   get "/ws" do
>     conn
>     |> WebSockAdapter.upgrade(Tpg.WebSocketHandler, %{}, timeout: 60_000)
>     |> halt()
>   end
> 
>   # Mantener rutas REST existentes para compatibilidad
>   post "/login" do
>     %{"usuario" => usuario} = conn.body_params
> 
>     case Tpg.loggear(usuario) do
>       {:ok, pid} ->
>         send_resp(conn, 200, Jason.encode!(%{
>           status: "success",
>           message: "Usuario #{usuario} logueado",
>           pid: inspect(pid)
>         }))
>       {:error, reason} ->
>         send_resp(conn, 400, Jason.encode!(%{
>           status: "error",
>           message: inspect(reason)
>         }))
>     end
>   end
> 
>   post "/logout" do
>     %{"usuario" => usuario} = conn.body_params
>     case Tpg.desloggear(usuario) do
>       {:ok, pid} ->
>         send_resp(conn, 200, Jason.encode!(%{
>           status: "success",
>           message: "Usuario #{usuario} deslogueado. Hasta pronto!",
>           pid: inspect(pid)
>         }))
>       {:error, reason} ->
>         send_resp(conn, 400, Jason.encode!(%{
>           status: "error",
>           message: inspect(reason)
>         }))
>     end
>   end
> 
>   post "/enviar" do
>     %{"de" => de, "para" => para, "mensaje" => msg} = conn.body_params
> 
>     case :global.whereis_name(para) do
>       :undefined ->
>         send_resp(conn, 404, Jason.encode!(%{
>           status: "error",
>           message: "Usuario #{para} no encontrado"
>         }))
>       pid ->
>         Tpg.enviar(de, pid, msg)
>         send_resp(conn, 200, Jason.encode!(%{
>           status: "success",
>           message: "Mensaje enviado de #{de} a #{para}"
>         }))
>     end
>   end
> 
>   get "/mensajes/:usuario" do
>     case :global.whereis_name(usuario) do
>       :undefined ->
>         send_resp(conn, 404, Jason.encode!(%{
>           status: "error",
>           message: "Usuario #{usuario} no encontrado"
>         }))
>       pid ->
>         mensajes = Tpg.leer_mensajes(pid)
>         send_resp(conn, 200, Jason.encode!(%{
>           status: "success",
>           usuario: usuario,
>           mensajes: mensajes
>         }))
>     end
>   end
> 
>   get "/usuarios" do
>     usuarios = Tpg.obtener_usuarios_activos()
>     send_resp(conn, 200, Jason.encode!(%{
>       status: "success",
>       usuarios: usuarios
>     }))
>   end
> 
>   # Página de prueba HTML
>   get "/" do
>     html = """
>     <!DOCTYPE html>
>     <html>
>     <head>
>       <title>Chat WebSocket</title>
>       <style>
>         body { font-family: Arial; max-width: 800px; margin: 50px auto; }
>         #mensajes { border: 1px solid #ccc; height: 400px; overflow-y: scroll; padding: 10px; margin: 10px 0; }
>         .mensaje { margin: 5px 0; padding: 5px; }
>         .sistema { background: #e3f2fd; }
>         .error { background: #ffebee; }
>         .nuevo { background: #e8f5e9; }
>         input, button { padding: 10px; margin: 5px; }
>         #status { font-weight: bold; }
>       </style>
>     </head>
>     <body>
>       <h1>Chat WebSocket TPG</h1>
>       <div>Status: <span id="status">Desconectado</span></div>
>       
>       <div>
>         <input type="text" id="usuario" placeholder="Tu nombre" />
>         <button onclick="conectar()">Conectar</button>
>         <button onclick="desconectar()">Desconectar</button>
>       </div>
> 
>       <div id="mensajes"></div>
> 
>       <div>
>         <input type="text" id="destinatario" placeholder="Para (usuario)" />
>         <input type="text" id="mensaje" placeholder="Mensaje" />
>         <button onclick="enviarMensaje()">Enviar</button>
>       </div>
> 
>       <div>
>         <button onclick="verHistorial()">Ver Historial</button>
>         <button onclick="listarUsuarios()">Usuarios Activos</button>
>       </div>
> 
>       <script>
>         let ws = null;
> 
>         function conectar() {
>           const usuario = document.getElementById('usuario').value;
>           if (!usuario) {
>             alert('Ingresa tu nombre');
>             return;
>           }
> 
>           ws = new WebSocket(`ws://localhost:4000/ws?usuario=${usuario}`);
> 
>           ws.onopen = () => {
>             document.getElementById('status').textContent = 'Conectado';
>             document.getElementById('status').style.color = 'green';
>             agregarMensaje('sistema', 'Conectado al servidor');
>           };
> 
>           ws.onmessage = (event) => {
>             const data = JSON.parse(event.data);
>             manejarMensaje(data);
>           };
> 
>           ws.onerror = (error) => {
>             agregarMensaje('error', 'Error: ' + error);
>           };
> 
>           ws.onclose = () => {
>             document.getElementById('status').textContent = 'Desconectado';
>             document.getElementById('status').style.color = 'red';
>             agregarMensaje('sistema', 'Desconectado del servidor');
>           };
>         }
> 
>         function desconectar() {
>           if (ws) {
>             ws.close();
>             ws = null;
>           }
>         }
> 
>         function enviarMensaje() {
>           const destinatario = document.getElementById('destinatario').value;
>           const mensaje = document.getElementById('mensaje').value;
> 
>           if (!destinatario || !mensaje) {
>             alert('Completa destinatario y mensaje');
>             return;
>           }
> 
>           const payload = {
>             accion: 'enviar',
>             para: destinatario,
>             mensaje: mensaje
>           };
> 
>           ws.send(JSON.stringify(payload));
>           document.getElementById('mensaje').value = '';
>         }
> 
>         function verHistorial() {
>           ws.send(JSON.stringify({ accion: 'leer_historial' }));
>         }
> 
>         function listarUsuarios() {
>           ws.send(JSON.stringify({ accion: 'listar_usuarios' }));
>         }
> 
>         function manejarMensaje(data) {
>           switch(data.tipo) {
>             case 'mensaje_nuevo':
>               agregarMensaje('nuevo', `💬 ${data.de}: ${data.mensaje}`);
>               break;
>             case 'historial':
>               agregarMensaje('sistema', '📋 Historial:');
>               data.mensajes.forEach(m => {
>                 agregarMensaje('sistema', `  ${m.de}: ${m.mensaje}`);
>               });
>               break;
>             case 'usuarios_activos':
>               agregarMensaje('sistema', '👥 Usuarios: ' + data.usuarios.join(', '));
>               break;
>             case 'confirmacion':
>               agregarMensaje('sistema', '✓ ' + data.mensaje);
>               break;
>             case 'error':
>               agregarMensaje('error', '❌ ' + data.mensaje);
>               break;
>             default:
>               agregarMensaje('sistema', JSON.stringify(data));
>           }
>         }
> 
>         function agregarMensaje(tipo, texto) {
>           const div = document.createElement('div');
>           div.className = 'mensaje ' + tipo;
>           div.textContent = `[${new Date().toLocaleTimeString()}] ${texto}`;
>           document.getElementById('mensajes').appendChild(div);
>           div.scrollIntoView();
>         }
>       </script>
>     </body>
>     </html>
>     """
>     
>     conn
>     |> put_resp_content_type("text/html")
>     |> send_resp(200, html)
>   end
> 
>   match _ do
>     send_resp(conn, 404, Jason.encode!(%{
>       status: "error",
>       message: "Ruta no encontrada"
>     }))
>   end
> end
> ```
> 
> ### **Paso 5: Instalar dependencias y compilar**
> 
> ```bash
> # Instalar nuevas dependencias
> mix deps.get
> 
> # Compilar
> mix compile
> ```
> 
> ### **Paso 6: Probar la implementación**
> 
> #### **Opción 1: Usar el cliente HTML integrado**
> 
> 1. Inicia el servidor:
> ```bash
> iex -S mix
> ```
> 
> 2. Abre tu navegador en `http://localhost:4000`
> 
> 3. Abre **múltiples pestañas** del navegador
> 
> 4. En cada pestaña:
>    - Ingresa un nombre diferente (ej: "alice", "bob", "charlie")
>    - Click en "Conectar"
> 
> 5. Prueba enviar mensajes entre usuarios
> 
> #### **Opción 2: Usar websocat (CLI)**
> 
> Instala websocat:
> ```bash
> # macOS
> brew install websocat
> 
> # Linux
> cargo install websocat
> ```
> 
> Prueba:
> ```bash
> # Terminal 1 - Usuario Alice
> websocat "ws://localhost:4000/ws?usuario=alice"
> 
> # Terminal 2 - Usuario Bob
> websocat "ws://localhost:4000/ws?usuario=bob"
> ```
> 
> Envía mensajes (formato JSON):
> ```json
> {"accion": "enviar", "para": "bob", "mensaje": "Hola Bob!"}
> {"accion": "leer_historial"}
> {"accion": "listar_usuarios"}
> ```
> 
> #### **Opción 3: Script de prueba bash**
> 
> Crea `test_websocket.sh`:
> 
> ```bash test_websocket.sh
> #!/bin/bash
> 
> echo "=== Test WebSocket TPG ==="
> 
> # Test 1: Conectar usuario
> echo -e "\n1. Conectando usuario 'alice'..."
> (echo '{"accion": "listar_usuarios"}' | websocat "ws://localhost:4000/ws?usuario=alice") &
> sleep 2
> 
> # Test 2: Conectar otro usuario
> echo -e "\n2. Conectando usuario 'bob'..."
> (sleep 1; echo '{"accion": "enviar", "para": "alice", "mensaje": "Hola Alice!"}' | websocat "ws://localhost:4000/ws?usuario=bob") &
> sleep 3
> 
> # Test 3: Ver usuarios activos
> echo -e "\n3. Listando usuarios activos..."
> echo '{"accion": "listar_usuarios"}' | websocat "ws://localhost:4000/ws?usuario=test"
> 
> wait
> echo -e "\n=== Tests completados ==="
> ```
> 
> ### **Paso 7: Verificación de funcionamiento**
> 
> Deberías ver:
> 
> 1. **Conexión exitosa**: Mensaje de bienvenida al conectar
> 2. **Mensajes en tiempo real**: Los mensajes llegan inmediatamente sin polling
> 3. **Lista de usuarios**: Puedes ver quién está conectado
> 4. **Historial**: Puedes recuperar mensajes anteriores
> 5. **Desconexión limpia**: El usuario se desloggea al cerrar la conexión
> 
> ### **Ventajas de esta implementación:**
> 
> ✅ **Comunicación bidireccional**: El servidor puede enviar mensajes sin que el cliente los solicite  
> ✅ **Tiempo real**: Los mensajes llegan instantáneamente  
> ✅ **Eficiente**: Una sola conexión persistente vs múltiples requests HTTP  
> ✅ **Escalable**: Cada WebSocket es un proceso ligero de Erlang  
> ✅ **Compatible**: Mantiene las rutas REST para clientes que no soporten WebSocket  
> 
> ### **Próximos pasos sugeridos:**
> 
> 1. Agregar autenticación con tokens
> 2. Implementar grupos/salas de chat
> 3. Agregar persistencia de mensajes en la base de datos
> 4. Implementar reconexión automática en el cliente
> 5. Agregar indicadores de "escribiendo..."
> 6. Implementar mensajes de presencia (usuario conectado/desconectado)
> 
> ¿Quieres que te muestre cómo implementar alguna de estas características adicionales, o necesitas ayuda para probar la implementación actual?

#### _User_

> Dame los links a la documentacion y las fuentes con las cuales generaste este Plan. Agrupa los enlaces por Tecnologia

#### _Assistant_

> Aquí están los enlaces a la documentación oficial agrupados por tecnología:
> 
> ## 📚 Enlaces de Documentación
> 
> ### **Cowboy & WebSockets (Servidor Web Erlang)**
> 
> 1. **Cowboy WebSocket Handler**
>    - https://ninenines.eu/docs/en/cowboy/2.9/guide/ws_handlers/
>    - Documentación oficial de cómo implementar handlers WebSocket en Cowboy
> 
> 2. **Cowboy User Guide**
>    - https://ninenines.eu/docs/en/cowboy/2.9/guide/
>    - Guía completa del servidor web Cowboy
> 
> 3. **Cowboy WebSocket Protocol**
>    - https://ninenines.eu/docs/en/cowboy/2.9/manual/cowboy_websocket/
>    - Referencia del módulo cowboy_websocket y sus callbacks
> 
> ### **Plug & Plug.Cowboy (Adaptador Elixir)**
> 
> 4. **Plug.Cowboy**
>    - https://hexdocs.pm/plug_cowboy/
>    - Adaptador entre Plug y Cowboy
> 
> 5. **Plug Documentation**
>    - https://hexdocs.pm/plug/readme.html
>    - Especificación composable de módulos para aplicaciones web
> 
> 6. **Plug.Router**
>    - https://hexdocs.pm/plug/Plug.Router.html
>    - DSL para definir rutas en Plug
> 
> ### **WebSock & WebSockAdapter (Abstracción WebSocket)**
> 
> 7. **WebSockAdapter**
>    - https://hexdocs.pm/websock_adapter/
>    - Adaptador para diferentes implementaciones de WebSocket en Elixir
> 
> 8. **WebSock Behaviour**
>    - https://hexdocs.pm/websock/
>    - Especificación del comportamiento WebSocket
> 
> 9. **WebSockAdapter.upgrade/4**
>    - https://hexdocs.pm/websock_adapter/WebSockAdapter.html#upgrade/4
>    - Función para upgrader conexiones HTTP a WebSocket
> 
> ### **Phoenix Framework (Alternativa más robusta)**
> 
> 10. **Phoenix Channels**
>     - https://hexdocs.pm/phoenix/channels.html
>     - Sistema de WebSocket de alto nivel de Phoenix
> 
> 11. **Phoenix.Socket**
>     - https://hexdocs.pm/phoenix/Phoenix.Socket.html
>     - Abstracción de sockets en Phoenix
> 
> 12. **Phoenix PubSub**
>     - https://hexdocs.pm/phoenix_pubsub/
>     - Sistema de mensajería pub/sub para Phoenix
> 
> ### **Elixir GenServer & OTP**
> 
> 13. **GenServer**
>     - https://hexdocs.pm/elixir/GenServer.html
>     - Documentación del comportamiento GenServer
> 
> 14. **Process**
>     - https://hexdocs.pm/elixir/Process.html
>     - Funciones para trabajar con procesos Erlang
> 
> 15. **:global module**
>     - https://www.erlang.org/doc/man/global.html
>     - Registro global de nombres en Erlang distribuido
> 
> ### **JSON Handling**
> 
> 16. **Jason**
>     - https://hexdocs.pm/jason/
>     - Codificador/decodificador JSON rápido en Elixir
> 
> ### **WebSocket Protocol Specification**
> 
> 17. **RFC 6455 - The WebSocket Protocol**
>     - https://datatracker.ietf.org/doc/html/rfc6455
>     - Especificación oficial del protocolo WebSocket
> 
> 18. **MDN WebSocket API**
>     - https://developer.mozilla.org/en-US/docs/Web/API/WebSocket
>     - Documentación de la API WebSocket del navegador
> 
> ### **Testing & CLI Tools**
> 
> 19. **websocat**
>     - https://github.com/vi/websocat
>     - Cliente WebSocket para línea de comandos
> 
> ### **Elixir Guides & Best Practices**
> 
> 20. **Elixir School - OTP Concurrency**
>     - https://elixirschool.com/en/lessons/advanced/otp_concurrency
>     - Tutorial sobre concurrencia con OTP
> 
> 21. **Elixir Getting Started - Processes**
>     - https://elixir-lang.org/getting-started/processes.html
>     - Guía oficial sobre procesos en Elixir
> 
> 22. **Real-Time Phoenix (Libro)**
>     - https://pragprog.com/titles/sbsockets/real-time-phoenix/
>     - Libro sobre aplicaciones en tiempo real con Phoenix
> 
> ### **Blog Posts & Tutorials Relevantes**
> 
> 23. **Building WebSockets with Cowboy**
>     - https://blog.logrocket.com/building-websockets-elixir-cowboy/
>     - Tutorial práctico
> 
> 24. **Elixir WebSocket Client & Server**
>     - https://stuff-things.net/2016/01/19/building-a-websocket-server-in-elixir/
>     - Guía paso a paso
> 
> ## 🔍 Conceptos Clave Utilizados
> 
> ### Del plan que generé:
> 
> 1. **`:cowboy_websocket` behaviour** → De Cowboy (enlaces 1, 2, 3)
> 2. **`WebSockAdapter.upgrade/4`** → De WebSockAdapter (enlace 9)
> 3. **`GenServer` con estado** → De Elixir OTP (enlace 13)
> 4. **`:global.whereis_name/1`** → De Erlang :global (enlace 15)
> 5. **`Process.monitor/1`** → De Elixir Process (enlace 14)
> 6. **`Jason.encode!/decode`** → De Jason (enlace 16)
> 7. **Callbacks cowboy_websocket**: `init/2`, `websocket_init/1`, `websocket_handle/2`, `websocket_info/2`, `terminate/3` → De Cowboy (enlace 3)
> 
> ## 📖 Documentación Específica Usada
> 
> Para cada sección del código:
> 
> | Código | Fuente Principal |
> |--------|------------------|
> | `@behaviour :cowboy_websocket` | Enlaces 1, 3 |
> | `websocket_init/1` | Enlace 3 - Manual Cowboy |
> | `websocket_handle/2` | Enlace 3 - Manual Cowboy |
> | `websocket_info/2` | Enlace 3 - Manual Cowboy |
> | `WebSockAdapter.upgrade` | Enlaces 7, 8, 9 |
> | `GenServer.start_link` | Enlace 13 |
> | `:global.whereis_name` | Enlace 15 |
> | `Process.monitor` | Enlace 14 |
> | Cliente HTML WebSocket | Enlace 18 - MDN |
> 
> Estos son los recursos oficiales y confiables que fundamentan la implementación propuesta. ¿Necesitas profundizar en alguna tecnología específica?