
let ws = null;

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
		listar_todos_usuarios();
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
	ws.send(JSON.stringify({ accion: 'listar_usuarios_db' }));
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
		case 'usuarios':
			listar_todos_usuarios(data.usuarios);
			break;
		case 'error':
			agregarMensaje('error', '❌ ' + data.mensaje);
			break;
		default:
			agregarMensaje('sistema', JSON.stringify(data));
	}
}

function listar_todos_usuarios(usuarios) {
	const lista = document.getElementById('lista-usuarios');
	lista.innerHTML = '';
	
	if (usuarios.length === 0) {
		const li = document.createElement('li');
		li.textContent = 'No hay usuarios conectados';
		li.style.color = '#999';
		lista.appendChild(li);
		return;
	}
	
	usuarios.forEach(usuario => {
		const li = document.createElement('li');
		li.id = usuario.receptor_id;
		li.textContent = usuario.nombre;
		lista.appendChild(li);
	});
}

function agregarMensaje(tipo, texto) {
	const div = document.createElement('div');
	div.className = 'mensaje ' + tipo;
	div.textContent = `[${new Date().toLocaleTimeString()}] ${texto}`;
	document.getElementById('mensajes').appendChild(div);
	div.scrollIntoView();
}