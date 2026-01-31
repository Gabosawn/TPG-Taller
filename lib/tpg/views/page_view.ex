defmodule Tpg.Views.PageView do
  def render_index do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Chat WebSocket</title>
      <link rel="icon" type="image/png" href="/static/img/cowboy.svg">
      <link rel="stylesheet" href="/static/style.css">
    </head>
    <body>
     <div class="header-container">
        <img src="/static/img/cowboy.png" alt="Logo" class="logo-header" />
        <h1>Chat WebSocket TPG</h1>
      </div>
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
          <div class="sidebar-tabs">
            <button id="btn-tab-conversaciones" class="sidebar-tab active" onclick="setSidebarView('conversaciones')">Conversaciones</button>
            <button id="btn-tab-notificaciones" class="sidebar-tab" onclick="setSidebarView('notificaciones')">Notificaciones</button>
          </div>
          <div id="chats-usuario">
            <ul id="lista-conversaciones"></ul>
          </div>
          <div id="notificaciones-usuario" hidden>
            <ul id="lista-notificaciones"></ul>
          </div>
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
        <button onclick="listarUsuarios()">Usuarios Activos</button>
      </div>
      <div>
        <button onclick="openModal('grupo')">Crear Grupo</button>
        <button onclick="openModal('contacto')">Agregar Contacto</button>
      </div>

      <div class="show-modal" style="display:none;">
        <div class="crear-grupo" style="display:none;">
          <h3>Crear Grupo</h3>
          <input type="text" id="nombre-grupo" placeholder="Nombre del grupo" />
          <div>
            <h4>Seleccionar miembros:</h4>
            <div id="usuarios-checkbox"></div>
          </div>
          <button onclick="crearGrupo()">Crear Grupo</button>
        </div>
        <div class="agregar-contacto" style="display:none;">
          <h3>Agregar Contacto</h3>
          <input type="text" id="nombre-usuario" placeholder="Nombre de Usuario" />
          <button onclick="agregarUsuario()">Agendar Contacto</button>
        </div>
      </div>

      <script>
        function openModal(modalType) {
          const showModal = document.querySelector('.show-modal');
          const crearGrupo = document.querySelector('.crear-grupo');
          const agregarContacto = document.querySelector('.agregar-contacto');

          crearGrupo.style.display = 'none';
          agregarContacto.style.display = 'none';

          if (modalType === 'grupo') {
            showModal.style.display = 'block';
            crearGrupo.style.display = 'block';
          } else if (modalType === 'contacto') {
            showModal.style.display = 'block';
            agregarContacto.style.display = 'block';
          }
        }

        function closeModal() {
          const showModal = document.querySelector('.show-modal');
          const crearGrupo = document.querySelector('.crear-grupo');
          const agregarContacto = document.querySelector('.agregar-contacto');

          showModal.style.display = 'none';
          crearGrupo.style.display = 'none';
          agregarContacto.style.display = 'none';
        }
      </script>
      <script src="/static/app.js"></script>
      <footer class="footer">
        <p>&copy; 2026 TPG Development Team. Todos los derechos reservados.</p>
        <div class="footer-emails">
          <p class="footer-email">johernandez@fi.uba.ar</p>
          <span class="separator">|</span>
          <p class="footer-email">gnarvaez@fi.uba.ar</p>
          <span class="separator">|</span>
          <p class="footer-email">flamanna@fi.uba.ar</p>
        </div>
      </footer>
    </body>
    </html>
    """
  end
end
