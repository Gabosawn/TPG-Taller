# Roadmap

## Funcionalidades
**V0.1**: Por medio de *iex* dos procesos deben poder enviarse mensajes entre si. 
Se requieren metodos para *crear*, *enviar_mensaje*, *leer_mensajes* [x]

**V0.2**: Por medio de *iex* se debe poder registrar y logear un usuario checkeando informacion con la base de datos imprimiendo "usuario logeado" y obtener un Process ID [x]

**V0.3**: Utilizando Ecto se deben poder persistir los mensajes que se envien. Esto es que los procesos al enviar un mensaje escriban en la tabla *mensajes* su contenido y destinatario (usuario-usuario) [x]

**V0.4**: Introducir el uso de salas grupales como procesos independientes usando GenServers de tipo `Runtime.Room` que distribuya el mismo mensaje que sea enviado alli, a todos sus suscriptores o participantes, esten conectados o no. Hacer que los procesos para estas salas sean levantados solo cuando haya uno o mas usuarios activos que esten suscriptos asi se hace mas eficiente el uso de recursos. [x]

**V0.5**: Utilizando la logica de los servicios de Logging y Chatting configurar las conexiones a los WebSockets con los Cowboy Handelers para que varios terminales puedan loggearse a la vez e interactuar.[x]

**V0.6**: Utilizando Ecto actualizar el estado de los mensajes a 'leido' cuando un proceso receptor envia una confirmacion al usuario emisor de que recibió su mensaje.
**V0.6.1**: Usuario-Usuario.
**V0.6.2**: Grupos.

**V0.7**: Utilizando Ecto se deben poder loggear un usuario por su ID de postgres y obtener el historial de los ultimos 10 mensajes que recibió recuperando su estado antes de su desconexion (simulada por un cierre de iex o GenServer.stop) (recuperacion de mensajes y bandeja de entrada)

**V0.8**: Utilizando DynamicSupervisor automatizar el ciclo de vida de los procesos de usuarios (para levantar procesos bajo demanda y luego de un tiempo que hibernen) hayando los PID's de los procesos en un Registry usando como clave el ID del usuario en la base de datos.

**V0.9**: Consultando en el Registry enviar al receptor un mensaje y que a este, si se encuentra activo, mostrarle el mensaje de manera instantanea como si tuviera la conversacion abierta en su UI. 
Ejemplo: 
1. Proceso Juan: Llama a Registry.lookup(ChatApp.Registry, 2).
2. Caso A (Maria Online): El Registry devuelve el PID de Maria. El proceso de Juan hace un GenServer.cast(pid_maria, {:nuevo_mensaje, msg}). Maria recibe el mensaje en su terminal instantáneamente.
3. Caso B (Maria Offline): El Registry devuelve []. El proceso de Juan solo escribe en la DB. Cuando Maria ejecute su V0.4 al loguearse más tarde, verá ese mensaje.




| **Capa**              |      **Responsabilidad**                |        **Componente Elixir**
|-----------------------|-----------------------------------------|------------------------------
| Identidad             | Autenticación y Tokens                  | LoginService
| Localización          | Encontrar procesos por ID               | Registry
| Ciclo de Vida         | Crear/Matar procesos de chat            | DynamicSupervisor
| Estado Vivo           | Lógica de usuario y sala en RAM         | GenServer
| Persistencia          | Guardado de mensajes y estados          | Ecto.Repo + PostgreSQL
