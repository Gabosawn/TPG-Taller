
let ws = null;
let chatActual = null

function setChatInputBloqueado(bloqueado, nombreContacto = '') {
	const chatInput = document.getElementById('chat-input-container');
	const bloqueadoEl = document.getElementById('chat-bloqueado');
	const bloqueadoTexto = document.getElementById('chat-bloqueado-texto');

	if (!chatInput || !bloqueadoEl) {
		return;
	}

	if (bloqueado) {
		chatInput.style.display = 'none';
		bloqueadoEl.style.display = '';
		if (bloqueadoTexto) {
			const nombre = nombreContacto ? `a ${nombreContacto}` : 'al contacto';
			bloqueadoTexto.textContent = `Agrega ${nombre} para poder enviar mensajes.`;
		}
	} else {
		bloqueadoEl.style.display = 'none';
		chatInput.style.display = '';
	}
}

function setSidebarView(view) {
	const chats = document.getElementById('chats-usuario');
	const notificaciones = document.getElementById('notificaciones-usuario');
	const btnConversaciones = document.getElementById('btn-tab-conversaciones');
	const btnNotificaciones = document.getElementById('btn-tab-notificaciones');

	if (!chats || !notificaciones || !btnConversaciones || !btnNotificaciones) {
		return;
	}

	if (view === 'notificaciones') {
		chats.hidden = true;
		notificaciones.hidden = false;
		btnConversaciones.classList.remove('active');
		btnNotificaciones.classList.add('active');
	} else {
		chats.hidden = false;
		notificaciones.hidden = true;
		btnNotificaciones.classList.remove('active');
		btnConversaciones.classList.add('active');
	}
}

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
	if (ws) {
		return;
	}
	ws = new WebSocket(`ws://localhost:4000/ws?operacion=crear&usuario=${usuario}&contrasenia=${contrasenia}`);

	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		manejarMensaje(data);
	};

	ws.onerror = (error) => {
		agregarMensajePrivado('error', 'Error: ' + error);
	};

	ws.onclose = () => {
		document.getElementById('status').textContent = 'Desconectado';
		document.getElementById('status').style.color = 'red';
		agregarMensajePrivado('sistema', 'Desconectado del servidor');
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
	if (ws) {
		return;
	}
	ws = new WebSocket(`ws://localhost:4000/ws?operacion=conectar&usuario=${usuario}&contrasenia=${contrasenia}`);
	
	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		manejarMensaje(data);
	};

	ws.onerror = (error) => {
		agregarMensajePrivado('error', 'Error: ' + error);
	};

	ws.onclose = () => {
		desconectar()
		document.getElementById('lista-notificaciones').innerHTML = '';
		document.getElementById('lista-conversaciones').innerHTML = '';
		document.getElementById('mensajes').innerHTML = '';
		document.getElementById('nombre-chat-actual').textContent = 'Selecciona un chat';
		document.getElementById('ultima-conexion').textContent = '';
		document.getElementById('usuarios-checkbox').innerHTML = '';
		chatActual = null;
	};
}

function desconectar() {
	if (ws) {
		ws.close();
		ws = null;
		document.getElementById('status').textContent = 'Desconectado';
		document.getElementById('status').style.color = 'red';
		agregarMensajePrivado('sistema', 'Desconectado del servidor');
	}
}

function manejarMensaje(data) {
	console.log("WS mensaje recibido:", data);
	switch (data.tipo) {
		case 'bienvenida':
			autorizar_usuario(data)
			break;
		case 'notificaciones':
			listar_notificaciones(data.notificaciones);
			break;
		case 'contactos':
			listar_contactos(data.conversaciones);
			break;
		case 'mensaje_nuevo_privado':
			mostrarMensajePrivado(data.user_ws_id, data.emisor, data.receptor, data.mensaje);
			break;
		case 'mensaje_nuevo_grupo':
			mostrarMensajeGrupo(data.user_ws_id, data.emisor, data.receptor, data.mensaje, data.emisor_nombre);
			break;
		case 'usuarios_activos':
			agregarMensajePrivado('sistema', '👥 Usuarios: ' + data.usuarios.join(', '));
			break;
		case 'confirmacion':
			agregarMensajePrivado('sistema', '✓ ' + data.mensaje);
			break;
		case 'contacto_nuevo':
			activarChatInput();
			agregarConversacion(data.contacto.tipo_contacto, data.contacto.receptor_id, data.contacto.nombre);
			agregarListaCrearGrupo(data.contacto.tipo_contacto, data.contacto.receptor_id, data.contacto.nombre);
			break;
		case 'notificacion_bandeja':
			agregarNotificacion(data.notificacion);
			break;
		case 'grupo_creado':
			agregarMensajePrivado('sistema', `✅ Grupo "${data.grupo}" creado con éxito.`);
			break;
		case 'chat_abierto_privado':
			mostrarChatPrivado(data.receptor, data.mensajes);
			break;
		case 'chat_abierto_grupo':
			mostrarChatGrupo(data.receptor, data.mensajes, data.kv_user_ids_names, data.user_ws_id); //REVISAR
			break;
		case 'error':
			agregarMensajePrivado('error', '❌ ' + data.mensaje);
			break;
		case 'sistema':
			mensajeDeSistema(data.mensaje);
			break;
		case 'notificacion_chat':
			agregarNotificacion(data)
			break;
		case 'contacto_en_linea':
			notificacion_punto_verde(true, data)
			break;
		case 'contacto_no_en_linea':
			notificacion_punto_verde(false, data)
			break;
		case 'do_nothing':
			break;

		default:
			agregarMensajePrivado('sistema', JSON.stringify(data));
	}
}

function mensajeDeSistema(mensaje) {
	console.log('Notificacion del sistema:', mensaje);
}

function notificacion_punto_verde(value, data) {
  const convId = data.notificacion.conversacion_id; // ejemplo: "privado-2"
  let conversacion = document.getElementById(convId);

  if (!conversacion) {
    console.warn("⚠️ No se encontró la conversacion, creando automáticamente...");
	return;
  }

  if (conversacion) {
	if (value) {
		conversacion.classList.add("punto-verde");
		console.log("✅ Punto verde agregado para", convId);
		return;
	} else {
		conversacion.classList.remove("punto-verde");
		console.log("✅ Punto verde removido para", convId);
		return;
	}
  }
}

function autorizar_usuario(payload) {
	document.getElementById('status').textContent = 'Conectado';
	document.getElementById('status').style.color = 'green';
	agregarMensajePrivado('sistema', payload.mensaje, payload.timestamp);
}

function agregarConversacion(tipo, id, nombre) {
	const lista = document.getElementById('lista-conversaciones');
	const li = document.createElement('li');
	li.id = `${tipo}-${id}`;
	li.textContent = nombre;
	li.className = 'chat-item';
	li.onclick = () => abrirChat(tipo, id);
	lista.appendChild(li);
}

function agregarListaCrearGrupo(tipo, id, nombre) {
	const checkboxContainer = document.getElementById('usuarios-checkbox');
	
	if (tipo !== "privado") { return; }
	const checkboxDiv = document.createElement('div');
	checkboxDiv.className = 'checkbox-item';
	
	const checkbox = document.createElement('input');
	checkbox.type = 'checkbox';
	checkbox.id = id;
	checkbox.value = id;
	
	const label = document.createElement('label');
	label.htmlFor = id;
	label.textContent = nombre;
	
	checkboxDiv.appendChild(checkbox);
	checkboxDiv.appendChild(label);
	checkboxContainer.appendChild(checkboxDiv);
}

function listar_contactos(conversaciones) {
	conversaciones.forEach(conversacion => {
		agregarConversacion(conversacion.tipo, conversacion.id, conversacion.nombre);
		agregarListaCrearGrupo(conversacion.tipo, conversacion.id, conversacion.nombre);
	});
}

function abrirChat(tipo, receptorId) {

	// Enviar solicitud para abrir el chat
	const payload = {
		accion: 'abrir_chat',
		tipo: tipo,
		receptor_id: receptorId
	};
	
	ws.send(JSON.stringify(payload));
}

function mostrarMensajePrivado(user_ws_id, emisor_id, receptor_id, mensaje) {
	console.log('Mostrando mensaje privado: ', mensaje, "del emisor: ", emisor_id, " al receptor: ",receptor_id);
	agregarMensajePrivado(user_ws_id == emisor_id ? 'enviado' : 'recibido', mensaje, mensaje.fecha);
}

function mostrarMensajeGrupo(user_ws_id, emisor_id, receptor_id, mensaje, nombre_emisor) {
	console.log('Mostrando mensaje de grupo: ', mensaje, "del emisor: ", emisor_id, " al receptor: ",receptor_id);
	agregarMensajeGrupo(user_ws_id == emisor_id ? 'enviado' : 'recibido', mensaje, mensaje.fecha, nombre_emisor);
}

function mostrarChatPrivado(usuario, mensajes) {
	chatActual = {tipo: usuario.tipo, nombre: usuario.nombre, id: usuario.receptor_id};

	// Remover clase active de todos los chats
	document.querySelectorAll('.chat-item').forEach(item => {
		item.classList.remove('active');
	});
	
	// Agregar clase active al chat seleccionado
	document.getElementById(`${usuario.tipo}-${usuario.receptor_id}`)?.classList.add('active');
	
	// Actualizar el header del chat
	document.getElementById('nombre-chat-actual').textContent = usuario.nombre;

	// Mostrar última conexión
	const ultimaConexionEl = document.getElementById('ultima-conexion');
	if (usuario.en_linea == 1) {
		ultimaConexionEl.textContent = 'En linea';
	} else if (ultimaConexionEl) {
		ultimaConexionEl.textContent = formatearUltimaConexion(usuario.ultima_conexion);
	}

	const esContacto = !!document.getElementById(`privado-${usuario.receptor_id}`);
	setChatInputBloqueado(!esContacto, usuario.nombre);
	
	const mensajesDiv = document.getElementById('mensajes');
	mensajesDiv.innerHTML = '';

	if (mensajes && mensajes.length > 0) {
		// Invertir el orden de los mensajes para mostrar el último primero
		mensajes.reverse().forEach(m => {
			agregarMensajePrivado(m.emisor == usuario.receptor_id ? 'recibido' : 'enviado', m.contenido, m.fecha);
		});
	} else {
		agregarMensajePrivado('sistema', 'No hay mensajes en esta conversación');
	}
}
function mostrarChatGrupo(grupo, mensajes, kv_user_ids_names, user_ws_id) {
	chatActual = { tipo: 'grupo', nombre: grupo.nombre, id: grupo.receptor_id };

	document.querySelectorAll('.chat-item').forEach(item => {
		item.classList.remove('active');
	});

	document.getElementById(`grupo-${grupo.receptor_id}`).classList.add('active');

	document.getElementById('nombre-chat-actual').textContent = grupo.nombre ?? 'Grupo desconocido';

	const ultimaConexionEl = document.getElementById('ultima-conexion');
	if (ultimaConexionEl) {
		ultimaConexionEl.textContent = '';
	}

	setChatInputBloqueado(false);

	const mensajesDiv = document.getElementById('mensajes');
	mensajesDiv.innerHTML = '';

	if (mensajes && mensajes.length > 0) {
		mensajes.reverse().forEach(m => {
			const tipo = m.emisor === user_ws_id ? 'enviado' : 'recibido';
			const nombreEmisor = kv_user_ids_names[m.emisor] ?? 'Desconocido';
			
			agregarMensajeGrupo(
				tipo,
				m.contenido,
				m.fecha,
				nombreEmisor
			);
		});
	} else {
		agregarMensajeGrupo(
			'sistema',
			'No hay mensajes en este grupo',
			null,
			''
		);
	}
}

function formatearUltimaConexion(fechaConexion) {
	if (!fechaConexion) return '';
	
	const fecha = new Date(fechaConexion);
	const ahora = new Date();
	const diferencia = ahora - fecha;
	
	const minutos = Math.floor(diferencia / 60000);
	const horas = Math.floor(diferencia / 3600000);
	const dias = Math.floor(diferencia / 86400000);
	
	if (minutos < 60) {
		return `Últ. vez hace ${minutos} min`;
	} else if (horas < 24) {
		return `Últ. vez hace ${horas} h`;
	} else if (dias < 7) {
		return `Últ. vez hace ${dias} d`;
	} else {
		return fecha.toLocaleDateString();
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
		tipo: chatActual.tipo,
		para: chatActual.id,
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

	if (miembros.length < 2) {
		alert('Selecciona al menos 2 miembros para el grupo');
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

function agregarPorModal() {
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

function agregarPorChat() {
	const payload = JSON.stringify({
		accion: "agregar_contacto",
		nombre_usuario: chatActual.nombre
	});

	ws.send(payload);
}

function agregarUsuario(origen) {
	if (origen === 'modal') {
		agregarPorModal();
	} else if (origen === 'chat') {
		console.log("Agregando usuario desde chat actual:", chatActual);
		agregarPorChat();
	}
}

function agregarMensajePrivado(tipo, texto, fecha) {
	console.log(`Agregando mensaje de tipo "${tipo}": ${texto}`);
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

function agregarMensajeGrupo(tipo, texto, fecha, emisor_nombre) {

	const div = document.createElement('div');
	div.className = 'mensaje ' + tipo;

	const emisor = document.createElement('strong');
	emisor.className = 'emisor';
	emisor.textContent = emisor_nombre;

	const contenido = document.createElement('span');
	contenido.textContent = texto;

	const timestamp = document.createElement('small');
	timestamp.className = 'timestamp';
	timestamp.textContent = fecha
		? new Date(fecha).toLocaleTimeString()
		: new Date().toLocaleTimeString();

	div.appendChild(emisor);
	div.appendChild(contenido);
	div.appendChild(timestamp);

	document.getElementById('mensajes').appendChild(div);
	div.scrollIntoView();
}

function listar_notificaciones(notificaciones) {
	const lista = document.getElementById('lista-notificaciones');

	if (notificaciones.length === 0) { return; }

	console.log("Listando notificaciones...");
	console.log(notificaciones);	

	notificaciones.forEach(notificacion => {
		agregarNotificacion(notificacion);
	});
}

function agregarNotificacion(notificacion) {
	const esListado = Array.isArray(notificacion.mensajes);
	let tipoChat = '';
	let receptorId = null;
	let nombre_contacto = '';
	let timestamp = null;
	let mensajeTexto = '';
	let cantidad = 1;

	if (esListado) {
		tipoChat = notificacion.tipo;
		receptorId = notificacion.receptor_id;
		const mensajes = notificacion.mensajes || [];
		cantidad = mensajes.length;
		const ultimo = mensajes.reduce((acc, curr) => {
			if (!acc) { return curr; }
			return new Date(curr.fecha) > new Date(acc.fecha) ? curr : acc;
		}, null);
		mensajeTexto = ultimo?.contenido ?? '';
		timestamp = ultimo?.fecha ?? null;
		const conversacionId = `${tipoChat}-${receptorId}`;
		if (tipoChat === 'privado') {
			nombre_contacto = ultimo?.emisor_nombre || `Privado #${receptorId}`;
		} else {
			const convEl = document.getElementById(conversacionId);
			nombre_contacto = convEl?.textContent || `Grupo #${receptorId}`;
		}
	} else {
		tipoChat = notificacion.conversacion_id.split('-')[0];
		receptorId = notificacion.receptor_id;
		if (tipoChat === 'privado') {
			nombre_contacto = notificacion.emisor_nombre || notificacion.nombre || `Privado #${receptorId}`;
		} else {
			const convEl = document.getElementById(`${tipoChat}-${receptorId}`);
			nombre_contacto = convEl?.textContent || notificacion.nombre || `Grupo #${receptorId}`;
		}
		timestamp = notificacion.fecha;
		mensajeTexto = notificacion.mensaje ?? '';
		cantidad = notificacion.cantidad ?? 1;
	}

	const bandeja = document.getElementById('lista-notificaciones');
	const li = document.createElement('li');
	li.className = 'notif-card';
	const header = document.createElement('div');
	header.className = 'notif-header';
	li.onclick = () => abrirChat(tipoChat, receptorId);

	header.innerHTML = `
		<span>${nombre_contacto}</span><span>${cantidad}</span>
	`
	li.appendChild(header);

	if (esListado) {
		const mensajes = notificacion.mensajes || [];
		mensajes.forEach(mensaje => {
			const row = document.createElement('div');
			row.className = 'notif-msg';
			const texto = document.createElement('span');
			texto.textContent = mensaje.contenido ?? '';
			const fecha = document.createElement('span');
			fecha.className = 'notif-time';
			fecha.textContent = mensaje.fecha ? new Date(mensaje.fecha).toLocaleString() : new Date().toLocaleString();
			row.appendChild(texto);
			row.appendChild(fecha);
			li.appendChild(row);
		});
	} else {
		const row = document.createElement('div');
		row.className = 'notif-msg';
		const texto = document.createElement('span');
		texto.textContent = mensajeTexto;
		const fecha = document.createElement('span');
		fecha.className = 'notif-time';
		fecha.textContent = timestamp ? new Date(timestamp).toLocaleString() : new Date().toLocaleString();
		row.appendChild(texto);
		row.appendChild(fecha);
		li.appendChild(row);
	}

	bandeja.appendChild(li);
}

function activarChatInput() {
	const chatInput = document.getElementById('chat-input-container');

	if (!chatInput) {
		return;
	}

	if (chatInput.style.display !== 'none') {
		return;
	}

	setChatInputBloqueado(false);
}