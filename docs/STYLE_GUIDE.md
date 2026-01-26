# Style Guide y Patrones deseados

## 🏗️ Estructura de Archivos

#### 1. Separación de Responsabilidades
```elixir
lib/tpg/
├── services/         # Lógica de negocio (funciones puras)
├── runtime/          # Procesos con estado (GenServers)
├── mensajes/         # Schemas de mensajería
├── receptores/       # Schemas de usuarios/grupos
└── handlers/         # Capa de red (WebSocket)
```

## Funciones

#### Uso Consistente de Pattern Matching
```elixir
case SessionService.loggear(operacion, usuario) do
  {:ok, res} -> 
    # flujo de éxito
  {:error, reason} -> 
    # flujo de error
end
```

#### Logging Estructurado
```elixir
# Formato consistente: [MODULO-CONTEXTO] Mensaje
Logger.info("[ROOM-#{group_id}] Usuario #{user_id} conectado")
Logger.warning("[Session service] sesion  no encontrada")
```

#### Inglés para funciones técnicas, español para dominio
``` elixir
def changeset(attrs)           # técnico
def iniciar_sesion(usuario)    # dominio
def obtener_mensajes(id)       # dominio
```
#### Convención de Nombres
```elixir
# Verbos en infinitivo para acciones
def enviar_mensaje(emisor, receptor, contenido)
def crear_usuario(attrs)
def obtener_historial(usuario_id)

# Predicados con "?"
def usuario_existe?(id)
def sala_activa?(room_id)
def puede_enviar?(usuario, destinatario)

# Transformaciones imperativas
def normalizar_texto(texto)
def formatear_fecha(datetime)
```

## Nomenclatura

### Módulos

#### Regla General
```elixir
# Formato: Tpg...

# Schemas de DB
Tpg.Dominio.Mensajes.Mensaje
Tpg.Dominio.Receptores.Usuario

# Servicios
Tpg.Services.ChatService
Tpg.Services.NotificationService

# Procesos Runtime
Tpg.Runtime.Session
Tpg.Runtime.Room
```

#### Convención de Alias
```elixir
# ✅ BIEN: Alias al inicio del módulo
defmodule Tpg.Services.ChatService do
  alias Tpg.Repo
  alias Tpg.Dominio.Mensajes.Mensaje
  alias Tpg.Services.NotificationService
  
  # código...
end

# ❌ EVITAR: Alias dentro de funciones
def enviar_mensaje do
  alias Tpg.Dominio.Mensajes.Mensaje
  # código...
end
```

## 🎯 Patrones de Diseño

### 1. Manejo de Errores con Railway-Oriented Programming

```elixir
# ✅ Encadenar operaciones con "with"
def procesar_mensaje(mensaje_params) do
  with {:ok, usuario} 
      {:error, "El usuario no existe"}
    
    {:error, :destinatario_offline} ->
      {:ok, mensaje}  # Mensaje guardado para entrega posterior
    
    {:error, changeset} ->
      {:error, changeset}
  end
end
```

### 3. Registry Pattern para Procesos

```elixir
# ✅ Usar via tuples para nombres dinámicos
defmodule Tpg.Runtime.Room do
  def start_link(group_id) do
    GenServer.start_link(__MODULE__, group_id, name: via_tuple(group_id))
  end

  defp via_tuple(group_id) do
    {:via, Registry, {Tpg.RoomRegistry, group_id}}
  end

  # Acceso desde cualquier lugar
  def enviar_mensaje(group_id, mensaje) do
    GenServer.call(via_tuple(group_id), {:agregar_mensaje, mensaje})
  end
end
```