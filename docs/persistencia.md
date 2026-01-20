
# Responsabilidades de la persistencia

## Tablas

- **Agendas**: almacena la relacion entre usuarios y sus contactos. Los contactos son otros usuarios con los cuales puede iniciar conversaciones. Solo se puede enviar mensajes a contactos agendados. Se pueden recibir mensajes de usuarios no agendados pero no contestarles a no ser que se les agende
- **Receptores**: Almacena la informacion base de los posibles tipos de chat que existen. En este caso pueden ser de dos tipos, GRUPO y USUARIO. Esta tabla es la tabla Padre de *usuarios* y *grupos*
- **Usuarios**: Almacena las credenciales de los usuario y su informacion personal. Tambien tiene informacion sobre cuando fue su ultima conexion
- **Usuarios_grupo**: Almacena la relacion de que usuarios perteneces a las conversaciones grupales.
- **Grupos**: Almacena la lista de grupos existentes, sus descripciones y su cantidad de miembros.
- **Enviados**: Guarda la relacion de mensajes y sus emisores. Permite conocer que usuarios enviaron cada mensaje
- **Recibidos**:  Guarda la relacion de los mensajes y quienes deben recibirlos. Estos pueden ser conversaciones privadas o grupales
- **Mensajes**: Guarda la informacion de los mensajes. Contenido, estado (entregado, recibido, leido) y fechas de insercion y modificacion

## Procesos

Cada que un usuario se registre se crea una nueva entrada en *usuarios*

Cuando un usuario intenta iniciar sesion se hace una lectura de la tabla *usuarios*

Un usuario logeado puede hacer una lectura de la tabla *agendas* para conocer los usuarios que tiene agendados

Tambien puede hacer inserciones para agregar nuevos usuarios existentes a su lista de contactos. Estos deben ser entidades ya en registradas

Un usuario puede crear una nueva conversacion insertando un mensaje en la tabla *mensajes* agregando un destinatario de su lista de contactos

Un usuario puede ver los mensajes de una conversacion leyendo de la tabla *mensajes* los que tengan como *receptor_id* su ID al unir esta tabla con la de *recibidos*

Un usuario puede crear grupos y agregar miembros agregando una entrada a la tabla *grupos* usando un nombre y una descripcion. El nombre no debe ser utilizado por otro grupo y los miembros deben ser usuarios registrados

