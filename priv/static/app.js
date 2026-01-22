
let ws = null;

function conectar() {
	const usuario = document.getElementById('usuario').value;
	if (!usuario) {
		alert('Ingresa tu nombre');
		return;
	}

	ws = new WebSocket(`ws://localhost:4000/ws?usuario=${usuario}`);

	ws.onopen = () => {
		document.getElementById('status').textContent = 'Conectado';
		document.getElementById('status').style.color = 'green';
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
		case 'error':
			agregarMensaje('error', '❌ ' + data.mensaje);
			break;
		default:
			agregarMensaje('sistema', JSON.stringify(data));
	}
}

function agregarMensaje(tipo, texto) {
	const div = document.createElement('div');
	div.className = 'mensaje ' + tipo;
	div.textContent = `[${new Date().toLocaleTimeString()}] ${texto}`;
	document.getElementById('mensajes').appendChild(div);
	div.scrollIntoView();
}