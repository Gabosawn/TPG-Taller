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

      mensaje = %Mensaje{contenido: "Hola mundo", estado: "ENVIADO"}

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

    test "falla cuando el contenido está vacío", %{emisor: emisor, receptor: receptor} do
      mensaje_vacio = %Mensaje{contenido: "", estado: "ENVIADO"}

      assert {:error, changeset} = Mensajeria.enviar_mensaje(
        receptor.receptor_id,
        emisor.receptor_id,
        mensaje_vacio
      )

      assert {:contenido, _} = List.keyfind(changeset.errors, :contenido, 0)
    end
  end

  describe "obtener_mensajes_usuarios/2" do
    test "obtiene mensajes entre dos usuarios" do
      {:ok, receptor_emisor} = Repo.insert(%Receptor{tipo: "Usuario"})
      {:ok, receptor_receptor} = Repo.insert(%Receptor{tipo: "Usuario"})

      {:ok, user_1} = Repo.insert(%Usuario{
        receptor_id: receptor_emisor.id,
        nombre: "emisorTest",
        contrasenia: "Test1234!",
        ultima_conexion: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      {:ok, user_2} = Repo.insert(%Usuario{
        receptor_id: receptor_receptor.id,
        nombre: "receptorTest",
        contrasenia: "Test1234!",
        ultima_conexion: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      mensajes = Mensajeria.obtener_mensajes_usuarios(user_1.receptor_id, user_2.receptor_id)

      assert length(mensajes) > 0
      assert Enum.all?(mensajes, fn msg ->
        (msg.emisor == user_1.receptor_id and msg.receptor == user_2.receptor_id) or
        (msg.emisor == user_2.receptor_id and msg.receptor == user_1.receptor_id)
      end)
    end
  end
end
