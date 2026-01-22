# Script para insertar datos iniciales en la base de datos
# Ejecutar con: mix run priv/repo/seeds.exs

alias Tpg.Repo
alias Tpg.Receptores.Cuentas

# Limpiar la base de datos (opcional, comentar si no se desea)
IO.puts("Limpiando base de datos...")
Repo.delete_all(Tpg.Receptores.UsuariosGrupo)
Repo.delete_all(Tpg.Receptores.Usuario)
Repo.delete_all(Tpg.Receptores.Grupo)
Repo.delete_all(Tpg.Receptores.Receptor)

IO.puts("Insertando datos de prueba...")

# Crear usuarios
{:ok, usuario1} = Cuentas.crear_usuario(%{
  nombre: "usuario001",
  contrasenia: "Password.123"
})
IO.puts("✓ Usuario creado: #{usuario1.nombre} (ID: #{usuario1.receptor_id})")

{:ok, usuario2} = Cuentas.crear_usuario(%{
  nombre: "usuario002",
  contrasenia: "Password.456"
})
IO.puts("✓ Usuario creado: #{usuario2.nombre} (ID: #{usuario2.receptor_id})")

{:ok, usuario3} = Cuentas.crear_usuario(%{
  nombre: "usuario003",
  contrasenia: "Password.789"
})
IO.puts("✓ Usuario creado: #{usuario3.nombre} (ID: #{usuario3.receptor_id})")

{:ok, usuario4} = Cuentas.crear_usuario(%{
  nombre: "juanperez",
  contrasenia: "Securepass.14"
})
IO.puts("✓ Usuario creado: #{usuario4.nombre} (ID: #{usuario4.receptor_id})")

{:ok, usuario5} = Cuentas.crear_usuario(%{
  nombre: "marialopez",
  contrasenia: "myPassword.14"
})
IO.puts("✓ Usuario creado: #{usuario5.nombre} (ID: #{usuario5.receptor_id})")

# Crear grupos con miembros
{:ok, grupo1} = Cuentas.crear_grupo(
  %{nombre: "Grupo Proyecto", descripcion: "Grupo para el proyecto final"},
  [usuario1.receptor_id, usuario2.receptor_id, usuario3.receptor_id]
)
IO.puts("✓ Grupo creado: #{grupo1.nombre} (ID: #{grupo1.receptor_id}) con 3 miembros")

{:ok, grupo2} = Cuentas.crear_grupo(
  %{nombre: "Equipo Dev", descripcion: "Equipo de desarrollo"},
  [usuario2.receptor_id, usuario4.receptor_id, usuario5.receptor_id]
)
IO.puts("✓ Grupo creado: #{grupo2.nombre} (ID: #{grupo2.receptor_id}) con 3 miembros")

{:ok, grupo3} = Cuentas.crear_grupo(
  %{nombre: "Amigos de la vda", descripcion: "Grupo de amigos"},
  [usuario1.receptor_id, usuario4.receptor_id, usuario5.receptor_id]
)
IO.puts("✓ Grupo creado: #{grupo3.nombre} (ID: #{grupo3.receptor_id}) con 3 miembros")

IO.puts("\n✅ Datos insertados correctamente!")
IO.puts("\nResumen:")
IO.puts("- 5 usuarios creados")
IO.puts("- 3 grupos creados")
