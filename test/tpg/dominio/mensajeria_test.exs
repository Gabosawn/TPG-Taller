defmodule Tpg.Dominio.MensajeriaTest do
  use Tpg.DataCase

  alias Tpg.Dominio.Mensajeria
  alias Tpg.Dominio.Mensajes.Mensaje
  alias Tpg.Dominio.Receptores.{Usuario, Receptor}

  describe "enviar_mensaje/3" do
    setup do
      # Crear datos de prueba
      {:ok, receptor_emisor} = Repo.insert(%Receptor{tipo: "Usuario"})
      {:ok, receptor_receptor} = Repo.insert(%Receptor{tipo: "Usuario"})

      {:ok, emisor} = Repo.insert(%Usuario{
        receptor_id: receptor_emisor.id,
        nombre: "emisorTest",
        contrasenia: "Test1234!",
        ultima_conexion: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      {:ok, receptor} = Repo.insert(%Usuario{
        receptor_id: receptor_receptor.id,
        nombre: "receptorTest",
        contrasenia: "Test1234!",
        ultima_conexion: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      mensaje = "Hola mundo"

      %{
        emisor: emisor,
        receptor: receptor,
        mensaje: mensaje
      }
    end

    test "envía un mensaje correctamente", %{emisor: emisor, receptor: receptor, mensaje: mensaje} do
      assert {:ok, mensaje_guardado} = Mensajeria.enviar_mensaje(
        receptor.receptor_id,
        emisor.receptor_id,
        mensaje
      )

      assert mensaje_guardado.contenido == "Hola mundo"
      assert mensaje_guardado.estado == "ENVIADO"
      assert mensaje_guardado.id != nil
    end

    test "falla cuando el emisor no existe", %{receptor: receptor, mensaje: mensaje} do
      assert {:error, changeset} = Mensajeria.enviar_mensaje(
        receptor.receptor_id,
        99999,  # ID que no existe
        mensaje
      )

      assert changeset.errors != []
    end

  end

end
