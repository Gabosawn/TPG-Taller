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

**Connection:** `ws://localhost:4000/ws?usuario=nombre_usuario`

#### Client Actions

| Action | Payload | Description |
|--------|---------|-------------|
| `enviar` | `{"accion": "enviar", "para": "destinatario", "mensaje": "texto"}` | Send message to user |
| `leer_historial` | `{"accion": "leer_historial"}` | Get message history |
| `listar_usuarios` | `{"accion": "listar_usuarios"}` | List active users |

#### Server Events

| Event Type | When | Payload Example |
|------------|------|-----------------|
| `sistema` | On connection | `{"tipo": "sistema", "mensaje": "Conectado como juan", "timestamp": "..."}` |
| `mensaje_nuevo` | New message received | `{"tipo": "mensaje_nuevo", "de": "maria", "mensaje": "hola", "timestamp": "..."}` |
| `confirmacion` | Message sent | `{"tipo": "confirmacion", "mensaje": "Mensaje enviado a pedro"}` |
| `historial` | History requested | `{"tipo": "historial", "mensajes": [...]}` |
| `usuarios_activos` | Users list requested | `{"tipo": "usuarios_activos", "usuarios": ["juan", "maria"]}` |
| `error` | Any error | `{"tipo": "error", "mensaje": "Usuario no encontrado"}` |

## Puertos
- Aplicación: http://localhost:4000
- PostgreSQL: localhost:5432

## Instrucciones de uso:

**Web client**:
http://localhost:4000 permite abrir multiples ventanas y chatear con otros usuarios en linea a la vez de dejar mensajes a otros usuarios para cuando se reconecten