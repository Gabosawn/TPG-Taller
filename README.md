# Tpg

Servicio de mensajeria instantanea Cliente-Servidor usando Cowboy, Ecto y GenServers.

## Dependencias Requeridas
- Docker y Docker Compose
- Elixir 1.15+
- Mix

## Setup Local
1. Clona el repositorio
2. Asegúrate que Docker esté corriendo
3. Ejecuta los siguientes comandos:

```bash
mix deps.get
docker compose up -d db
mix ecto.crete
mix setup_db
```
Una vez conseguido esto ya tendremos la base de datos lista dentro de nuestro contenedor de docker.

## Ejecutar en Desarrollo
```bash
# Opción 1: Con iex
iex -S mix

#TODO: # Opción 2: Como servidor HTTP 
mix phx.server

# Opción 3: Con Docker
docker compose up --build web-server
```
Al ejecutarlo con iex ya se levanta el servidor de manera local y comienza a escuchar y servir desde el puerto 4000 (permite desarrollar y hacer 'recompile' dentro de la consola)
De la misma manera se puede ejecutar el servidor dentro de un contenedor de docker sobre el mismo puerto 4000 (simula un deploy)
## API Endpoints

### Autenticación
- `POST /login` - Loguear usuario
  ```json
  {"usuario": "juan"}
  ```

### Mensajería
- `POST /enviar` - Enviar mensaje
  ```json
  {"de": "juan", "para": "maria", "mensaje": "Hola!"}
  ```

- `GET /mensajes/:usuario` - Leer mensajes del usuario

### Utilidades
- `GET /usuarios` - Listar usuarios activos

### WebSocket API

**Connection:** `ws://localhost:4000/ws`

#### Connection Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `operacion` | Yes | `crear` (register) or `conectar` (login) |
| `usuario` | Yes | Username |
| `contrasenia` | Yes | Password |

**Example:** `ws://localhost:4000/ws?operacion=conectar&usuario=juan&contrasenia=123456`

#### Client Actions

| Action | Payload | Description |
|--------|---------|-------------|
| `enviar` | `{"accion": "enviar", "tipo": "privado"/"grupo", "para": "id", "mensaje": "texto"}` | Envia mensaje a usuario o grupo |
| `abrir_chat` | `{"accion": "abrir_chat", "tipo": "privado"/"grupo", "receptor_id": "id"}` | Abre un chat y consigue su historial |
| `crear_grupo` | `{"accion": "crear_grupo", "nombre": "nombre_grupo", "miembros": ["id1", "id2"]}` | Crea un nuevo grupo |
| `agregar_contacto` | `{"accion": "agregar_contacto", "nombre_usuario": "usuario"}` | Agrega un usuario como contacto |
#### Server Events

| Tipo de Evento | Cuándo | Ejemplo de Payload |
|----------------|--------|-------------------|
| `bienvenida` | Al conectarse exitosamente | `{"tipo": "bienvenida", "mensaje": "Conectado como juan", "timestamp": "..."}` |
| `mensaje_nuevo_privado` | Mensaje privado recibido | `{"tipo": "mensaje_nuevo_privado", "user_ws_id": "1", "emisor": "2", "receptor": "1", "mensaje": {...}}` |
| `mensaje_nuevo_grupo` | Mensaje de grupo recibido | `{"tipo": "mensaje_nuevo_grupo", "user_ws_id": "1", "emisor": "2", "receptor": "3", "mensaje": {...}, "emisor_nombre": "maria"}` |
| `chat_abierto_privado` | Chat privado abierto | `{"tipo": "chat_abierto_privado", "receptor": {...}, "mensajes": [...]}` |
| `chat_abierto_grupo` | Chat de grupo abierto | `{"tipo": "chat_abierto_grupo", "receptor": {...}, "mensajes": [...], "kv_user_ids_names": {...}, "user_ws_id": "1"}` |
| `contactos` | Lista de contactos | `{"tipo": "contactos", "conversaciones": [{"tipo": "privado", "id": "2", "nombre": "maria"}]}` |
| `notificaciones` | Lista de notificaciones | `{"tipo": "notificaciones", "notificaciones": [...]}` |
| `contacto_nuevo` | Nuevo contacto agregado | `{"tipo": "contacto_nuevo", "contacto": {"tipo_contacto": "privado", "receptor_id": "2", "nombre": "pedro"}}` |
| `grupo_creado` | Grupo creado | `{"tipo": "grupo_creado", "grupo": "nombre_grupo"}` |
| `contacto_en_linea` | Contacto se conecta | `{"tipo": "contacto_en_linea", "notificacion": {"conversacion_id": "privado-2"}}` |
| `contacto_no_en_linea` | Contacto se desconecta | `{"tipo": "contacto_no_en_linea", "notificacion": {"conversacion_id": "privado-2"}}` |
| `notificacion_bandeja` | Nueva notificación | `{"tipo": "notificacion_bandeja", "notificacion": {...}}` |
| `error` | Cualquier error | `{"tipo": "error", "mensaje": "Usuario no encontrado"}` |
| `sistema` | Mensaje del sistema | `{"tipo": "sistema", "mensaje": "Sistema actualizado"}` |

## Puertos
- Aplicación: http://localhost:4000
- PostgreSQL: localhost:5432

## Instrucciones de uso:

**Web client**:
http://localhost:4000 permite abrir multiples ventanas y chatear con otros usuarios en linea a la vez de dejar mensajes a otros usuarios para cuando se reconecten

## Testing
- `mix test` para correr los tests unitarios
- `mix test --cover` para correr las pruebas y generar archivos de cobertura
- `docker compose up -d cover-server` para levantar el servidor de cobertura de codigo y ver los resultados en tiempo real
- http://localhost:8080 para ver la interfaz de cobertura  