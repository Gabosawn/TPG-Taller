
let ws = null;
let chatActual = null

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
			listar_notificaciones(data.tipo_chat, data.emisor_id ,data.mensajes);
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
			agregarConversacion(data.contacto.tipo_contacto, data.contacto.receptor_id, data.contacto.nombre);
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
	li.onclick = () => abrirChat(tipo, id, nombre);
	lista.appendChild(li);
}

function agregarListaCrearGrupo(checkboxContainer, tipo, id, nombre) {
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
	const lista = document.getElementById('lista-conversaciones');
	lista.innerHTML = '';
	const checkboxContainer = document.getElementById('usuarios-checkbox');
	checkboxContainer.innerHTML = ''

	conversaciones.forEach(conversacion => {
		agregarConversacion(conversacion.tipo, conversacion.id, conversacion.nombre);
		agregarListaCrearGrupo(checkboxContainer, conversacion.tipo, conversacion.id, conversacion.nombre);
	});
}

function abrirChat(tipo, receptorId, nombreReceptor) {

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
	chatActual = {tipo: usuario.tipo, id: usuario.receptor_id};

	// Remover clase active de todos los chats
	document.querySelectorAll('.chat-item').forEach(item => {
		item.classList.remove('active');
	});
	
	// Agregar clase active al chat seleccionado
	document.getElementById(`${usuario.tipo}-${usuario.receptor_id}`).classList.add('active');
	
	// Actualizar el header del chat
	document.getElementById('nombre-chat-actual').textContent = usuario.nombre;

	// Mostrar última conexión
	const ultimaConexionEl = document.getElementById('ultima-conexion');
	if (ultimaConexionEl) {
		ultimaConexionEl.textContent = formatearUltimaConexion(usuario.ultima_conexion);
	}
	
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
	chatActual = { tipo: 'grupo', id: grupo.receptor_id };

	document.querySelectorAll('.chat-item').forEach(item => {
		item.classList.remove('active');
	});

	document.getElementById(`grupo-${grupo.receptor_id}`).classList.add('active');

	document.getElementById('nombre-chat-actual').textContent = grupo.nombre ?? 'Grupo desconocido';

	const ultimaConexionEl = document.getElementById('ultima-conexion');
	if (ultimaConexionEl) {
		ultimaConexionEl.textContent = '';
	}

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


function listar_notificaciones(tipo_chat, emisor_id, mensajes) {
	const lista = document.getElementById('lista-notificaciones');

	const tipoChat = tipo_chat ?? 'Usuario';
	const emisorIdPayload = emisor_id ?? null;
	const nombrePayload = null;
	if(mensajes.length === 0) {return;}
	const chatItemId = `${tipoChat}-${emisorIdPayload ?? ''}`.trim();
	if (chatItemId) {
		const chatItem = document.getElementById(chatItemId);
		if (chatItem) chatItem.classList.add('has-notif');
	}

	const agrupadas = mensajes.reduce((acc, notificacion) => {
		const key = notificacion.emisor ?? 'desconocido';
		if (!acc[key]) acc[key] = [];
		acc[key].push(notificacion);
		return acc;
	}, {});

	Object.entries(agrupadas).forEach(([emisor, msgs]) => {
		const card = document.createElement('li');
		card.className = 'notif-card';

		const header = document.createElement('div');
		header.className = 'notif-header';
		const nombre_contacto = document.getElementById(`${tipoChat}-${emisorIdPayload}`).outerText;
		const nombre = nombrePayload ?? (tipoChat === 'Grupo' ? `Grupo ${emisor}` : `Usuario ${emisor}`);
		header.innerHTML = `<span>${nombre_contacto}</span><span>${msgs.length}</span>`;
		card.appendChild(header);

		card.onclick = () => abrirChat(tipoChat, nombre_contacto, nombre);

		msgs.forEach(m => {
			const row = document.createElement('div');
			row.className = 'notif-msg';
			const texto = document.createElement('span');
			texto.textContent = m.contenido ?? '';

			const fecha = document.createElement('span');
			fecha.className = 'notif-time';
			fecha.textContent = m.fecha ? new Date(m.fecha).toLocaleString() : '';

			row.appendChild(texto);
			row.appendChild(fecha);
			card.appendChild(row);
		});

		lista.appendChild(card);
	});
}

function agregarNotificacion(notificacion) {
	const tipoChat = notificacion.conversacion_id.split('-')[0]
	const nombre_contacto = notificacion.nombre
	const timestamp = notificacion.fecha
	const bandeja = document.getElementById('lista-notificaciones');
	const li = document.createElement('li');
	li.className = 'notif-card';
	const header = document.createElement('div');
	header.className = 'notif-header';
	li.onclick = () => abrirChat(tipoChat, notificacion.receptor_id, nombre_contacto);

	header.innerHTML = `
		<span>${nombre_contacto}</span><span>1</span>
	`
	const row = document.createElement('div');
	row.className = 'notif-msg';
	const texto = document.createElement('span');
	texto.textContent = notificacion.mensaje ?? '';

	const fecha = document.createElement('span');
	fecha.className = 'notif-time';
	fecha.textContent = timestamp ? new Date(timestamp).toLocaleString() : new Date().toLocaleString();

	li.appendChild(header);
	row.appendChild(texto);
	row.appendChild(fecha);
	li.appendChild(row);
	bandeja.appendChild(li);
}