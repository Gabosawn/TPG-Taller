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
docker compose up -d
mix setup_db
```
Una vez conseguido esto ya tendremos la base de datos lista dentro de nuestro contenedor de docker.

## Ejecutar en Desarrollo
```bash
# Opción 1: Con iex
iex -S mix

#TODO: # Opción 2: Como servidor HTTP 
mix phx.server

#TODO: # Opción 3: Con Docker
docker compose up --build
```
Al ejecutarlo con iex ya se levanta el servidor de manera local y comienza a escuchar y servir desde el puerto 4000

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

## Puertos
- Aplicación: http://localhost:4000
- PostgreSQL: localhost:5432

## Instrucciones de uso:

**Ejecutar**: 
```bash
./test_tpg.sh
```