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
        <button onclick="conectar()">Conectar</button>
        <button onclick="desconectar()">Desconectar</button>
      </div>

      <div id="mensajes"></div>

      <div>
        <input type="text" id="destinatario" placeholder="Para (usuario)" />
        <input type="text" id="mensaje" placeholder="Mensaje" />
        <button onclick="enviarMensaje()">Enviar</button>
      </div>

      <div>
        <button onclick="verHistorial()">Ver Historial</button>
        <button onclick="listarUsuarios()">Usuarios Activos</button>
      </div>

      <script src="/static/app.js"></script>
    </body>
    </html>
    """
  end
end
