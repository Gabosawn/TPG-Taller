defmodule Mix.Tasks.SetupApp do
  use Mix.Task

  @shortdoc "Configura la aplicación completamente"
  def run(_args) do
    # Limpiar y preparar dependencias
    Mix.Task.run("deps.clean", ["--all"])
    Mix.Task.run("deps.get")
    Mix.Task.run("deps.compile")

    # Crear base de datos
    Mix.Task.run("ecto.drop")
    Mix.Task.run("ecto.create")
    Mix.Task.run("ecto.migrate")

    # Mensaje de éxito
    Mix.Shell.IO.info("Aplicación configurada exitosamente!")
  end
end
