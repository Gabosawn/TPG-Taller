# lib/tpg/views/page_view.ex
defmodule Tpg.Views.PageView do
  def render_index do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Chat WebSocket</title>
      <link rel="stylesheet" href="/static/style.css">
    </head>
    <body>
      <h1>Chat WebSocket TPG</h1>
      <div>Status: <span id="status">Desconectado</span></div>

      <div>
        <input type="text" id="usuario" placeholder="Tu nombre" />
        <input type="text" id="contrasenia" placeholder="Tu contraseña" />
        <button onclick="registrar()">Registrar</button>
        <button onclick="conectar()">Conectar</button>
        <button onclick="desconectar()">Desconectar</button>
      </div>

      <div class="chat-container">
        <div class="sidebar">
          <h3>Conversaciones</h3>
          <ul id="lista-conversaciones"></ul>
        </div>

        <div class="chat-area">
          <div class="chat-header">
            <div id="nombre-chat-actual">Selecciona un chat</div>
          </div>

          <div id="mensajes"></div>

          <div class="chat-input">
            <input type="text" id="mensaje" placeholder="Escribe un mensaje..." />
            <button onclick="enviarMensaje()">Enviar</button>
          </div>
        </div>
      </div>

      <div>
        <button onclick="verHistorial()">Ver Historial</button>
        <button onclick="listarUsuarios()">Usuarios Activos</button>
      </div>
      <button id="displayCrearGrupo">Crear Grupo</button>

      <div class="crear-grupo" style="display:none;">
        <h3>Crear Grupo</h3>
        <input type="text" id="nombre-grupo" placeholder="Nombre del grupo" />
        <div>
          <h4>Seleccionar miembros:</h4>
          <div id="usuarios-checkbox"></div>
        </div>
        <button onclick="crearGrupo()">Crear Grupo</button>
      </div>
      <script src="/static/app.js"></script>
    </body>
    </html>
    """
  end
end
