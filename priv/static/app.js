
let ws = null;
let chatActual = null
document.getElementById('lista-usuarios')



function registrar() {
	const usuario = document.getElementById('usuario').value;
	const contrasenia = document.getElementById('contrasenia').value;

	if (!usuario) {
		alert('Ingresa tu nombre');
		return;
	}

	if (!contrasenia) {
		alert('Ingresa tu contraseña');
		return;
	}

	ws = new WebSocket(`ws://localhost:4000/ws?operacion=crear&usuario=${usuario}&contrasenia=${contrasenia}`);

	ws.onopen = () => {
		document.getElementById('status').textContent = 'Conectado';
		document.getElementById('status').style.color = 'green';
		listarTodosLosUsuarios();
		agregarMensaje('sistema', 'Conectado al servidor');
	};

	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		manejarMensaje(data);
	};

	ws.onerror = (error) => {
		agregarMensaje('error', 'Error: ' + error);
	};

	ws.onclose = () => {
		document.getElementById('status').textContent = 'Desconectado';
		document.getElementById('status').style.color = 'red';
		agregarMensaje('sistema', 'Desconectado del servidor');
	};
}

function conectar() {
	const usuario = document.getElementById('usuario').value;
	const contrasenia = document.getElementById('contrasenia').value;

	if (!usuario) {
		alert('Ingresa tu nombre');
		return;
	}

	if (!contrasenia) {
		alert('Ingresa tu contraseña');
		return;
	}

	ws = new WebSocket(`ws://localhost:4000/ws?operacion=conectar&usuario=${usuario}&contrasenia=${contrasenia}`);

	ws.onopen = () => {
		document.getElementById('status').textContent = 'Conectado';
		document.getElementById('status').style.color = 'green';
		agregarMensaje('sistema', 'Conectado al servidor');
		listarTodosLosUsuarios();
		listarConversaciones();
		obtenerContactos();
	};
	
	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		manejarMensaje(data);
	};

	ws.onerror = (error) => {
		agregarMensaje('error', 'Error: ' + error);
	};

	ws.onclose = () => {
		document.getElementById('status').textContent = 'Desconectado';
		document.getElementById('status').style.color = 'red';
		agregarMensaje('sistema', 'Desconectado del servidor');
	};
}

function desconectar() {
	if (ws) {
		ws.close();
		ws = null;
	}
}

function enviarMensaje() {
	const destinatario = document.getElementById('destinatario').value;
	const mensaje = document.getElementById('mensaje').value;

	if (!destinatario || !mensaje) {
		alert('Completa destinatario y mensaje');
		return;
	}

	const payload = {
		accion: 'enviar',
		para: destinatario,
		mensaje: mensaje
	};

	ws.send(JSON.stringify(payload));
	document.getElementById('mensaje').value = '';
}

function verHistorial() {
	ws.send(JSON.stringify({ accion: 'leer_historial' }));
}

function listarUsuarios() {
	ws.send(JSON.stringify({ accion: 'listar_usuarios' }));
}

function listarTodosLosUsuarios() {
	ws.send(JSON.stringify({ accion: 'listar_usuarios_db' }));
}

function listarConversaciones() {
	ws.send(JSON.stringify({ accion: 'listar_conversaciones' }));
}

function manejarMensaje(data) {
	switch (data.tipo) {
		case 'mensaje_nuevo':
			agregarMensaje('nuevo', `💬 ${data.de}: ${data.mensaje}`);
			break;
		case 'historial':
			agregarMensaje('sistema', '📋 Historial:');
			data.mensajes.forEach(m => {
				agregarMensaje('sistema', `  ${m.de}: ${m.mensaje}`);
			});
			break;
		case 'usuarios_activos':
			agregarMensaje('sistema', '👥 Usuarios: ' + data.usuarios.join(', '));
			break;
		case 'confirmacion':
			agregarMensaje('sistema', '✓ ' + data.mensaje);
			break;

		case 'listar_conversaciones':
			listar_conversaciones_response(data.conversaciones);
			break;

		case 'grupo_creado':
			agregarMensaje('sistema', `✅ Grupo "${data.grupo}" creado con éxito.`);
			break;
		case 'usuarios':
			listar_todos_usuarios(data.usuarios);
			break;
		case 'listar_usuarios_db':
			listar_usuarios_agrupables(data.usuarios)
		case 'chat_abierto':
			mostrarChat(data.receptor_id, data.mensajes);
			break;
		case 'error':
			agregarMensaje('error', '❌ ' + data.mensaje);
			break;
		default:
			agregarMensaje('sistema', JSON.stringify(data));
	}
}

function listar_conversaciones_response(conversaciones) {
	const lista = document.getElementById('lista-conversaciones');
	lista.innerHTML = '';

	if (conversaciones.length === 0) {
		const li = document.createElement('li');
		li.textContent = 'No hay conversaciones';
		li.style.color = '#999';
		lista.appendChild(li);
		return;
	}
	

	conversaciones.forEach(conversacion => {
		const li = document.createElement('li');
		li.id = conversacion.id;
		li.textContent = conversacion.nombre;
		li.className = 'chat-item';
		li.onclick = () => abrirChat(conversacion.id, conversacion.nombre);
		lista.appendChild(li);
	});
}

function listar_usuarios_agrupables(usuarios) {
	const lista = document.getElementById('lista-usuarios');
	lista.innerHTML = '';
	
	const checkboxContainer = document.getElementById('usuarios-checkbox');
	checkboxContainer.innerHTML = '';
	
	if (usuarios.length === 0) {
		const li = document.createElement('li');
		li.textContent = 'No hay usuarios conectados';
		li.style.color = '#999';
		lista.appendChild(li);
		return;
	}
	
	usuarios.forEach(usuario => {
		// Crear checkbox para selección de grupo
		const checkboxDiv = document.createElement('div');
		checkboxDiv.className = 'checkbox-item';
		
		const checkbox = document.createElement('input');
		checkbox.type = 'checkbox';
		checkbox.id = usuario.receptor_id;
		checkbox.value = usuario.receptor_id;
		
		const label = document.createElement('label');
		label.htmlFor = usuario.receptor_id;
		label.textContent = usuario.nombre;
		
		checkboxDiv.appendChild(checkbox);
		checkboxDiv.appendChild(label);
		checkboxContainer.appendChild(checkboxDiv);
	});
}

function abrirChat(receptorId, nombreReceptor) {
	chatActual = receptorId;
	
	// Remover clase active de todos los chats
	document.querySelectorAll('.chat-item').forEach(item => {
		item.classList.remove('active');
	});
	
	// Agregar clase active al chat seleccionado
	document.getElementById(receptorId).classList.add('active');
	
	// Actualizar el header del chat
	document.getElementById('nombre-chat-actual').textContent = nombreReceptor;
	
	// Enviar solicitud para abrir el chat
	const payload = {
		accion: 'abrir_chat',
		receptor_id: receptorId
	};
	
	ws.send(JSON.stringify(payload));
}

function mostrarChat(receptorId, mensajes) {
	console.log('Mostrando chat con receptor ID:', receptorId);
	console.log('Mensajes recibidos:', mensajes);
	const mensajesDiv = document.getElementById('mensajes');
	mensajesDiv.innerHTML = '';

	if (mensajes && mensajes.length > 0) {
		mensajes.forEach(m => {
			agregarMensaje(m.emisor == receptorId ? 'enviado' : 'recibido', m.contenido, m.fecha);
		});
	} else {
		agregarMensaje('sistema', 'No hay mensajes en esta conversación');
	}
}

function enviarMensaje() {
	const mensaje = document.getElementById('mensaje').value;

	if (!mensaje) {
		alert('Escribe un mensaje');
		return;
	}
	
	if (!chatActual) {
		alert('Selecciona un chat primero');
		return;
	}

	const payload = {
		accion: 'enviar',
		para: chatActual,
		mensaje: mensaje
	};

	ws.send(JSON.stringify(payload));
	document.getElementById('mensaje').value = '';
}


function crearGrupo() {
	const nombreGrupo = document.getElementById('nombre-grupo').value;
	
	if (!nombreGrupo) {
		alert('Ingresa un nombre para el grupo');
		return;
	}
	
	const checkboxes = document.querySelectorAll('#usuarios-checkbox input[type="checkbox"]:checked');
	const miembros = Array.from(checkboxes).map(cb => cb.value);

	if (miembros.length < 3) {
		alert('Selecciona al menos 3 miembros para el grupo');
		return;
	}
	
	const payload = {
		accion: 'crear_grupo',
		nombre: nombreGrupo,
		miembros: miembros
	};
	
	ws.send(JSON.stringify(payload));
	
	document.getElementById('nombre-grupo').value = '';
	checkboxes.forEach(cb => cb.checked = false);
}

function agregarUsuario() {
  const nombreUsuario = document.getElementById('nombre-usuario').value.trim();
  if (!nombreUsuario) {
    alert('Por favor ingresa un nombre de usuario');
    return;
  }
  const payload = JSON.stringify({
    accion: "agregar_contacto",
    nombre_usuario: nombreUsuario
  });
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(payload);
    // Limpiar el input y cerrar el modal
    document.getElementById('nombre-usuario').value = '';
    closeModal();
  } else {
    alert('No hay conexión con el servidor');
  }
}

function agregarMensaje(tipo, texto, fecha) {
	const div = document.createElement('div');
	div.className = 'mensaje ' + tipo;
	
	const contenido = document.createElement('span');
	contenido.textContent = texto;
	
	const timestamp = document.createElement('small');
	timestamp.className = 'timestamp';
	timestamp.textContent = fecha ? new Date(fecha).toLocaleTimeString() : new Date().toLocaleTimeString();
	
	div.appendChild(contenido);
	div.appendChild(timestamp);
	
	document.getElementById('mensajes').appendChild(div);
	div.scrollIntoView();
}
