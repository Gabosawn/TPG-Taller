defmodule Tpg.Router do
  @deprecated
  use Plug.Router

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(Plug.Static, at: "/static", from: :tpg)
  plug(:match)
  plug(:dispatch)

  post "/login" do
    %{"usuario" => usuario} = conn.body_params

    case Tpg.loggear(:conectar, usuario) do
      {:ok, pid} ->
        send_resp(
          conn,
          200,
          Jason.encode!(%{
            status: "success",
            message: "Usuario #{usuario} logueado",
            pid: inspect(pid)
          })
        )

      {:error, reason} ->
        send_resp(
          conn,
          400,
          Jason.encode!(%{
            status: "error",
            message: inspect(reason)
          })
        )
    end
  end

  post "/logout" do
    %{"usuario" => usuario} = conn.body_params

    case Tpg.desloggear(usuario) do
      {:ok, pid} ->
        send_resp(
          conn,
          200,
          Jason.encode!(%{
            status: "success",
            message: "Usuario #{usuario} deslogueado. Hasta pronto!",
            pid: inspect(pid)
          })
        )

      {:error, reason} ->
        send_resp(
          conn,
          400,
          Jason.encode!(%{
            status: "error",
            message: inspect(reason)
          })
        )
    end
  end

  post "/enviar" do
    %{"de" => de, "para" => para, "mensaje" => msg} = conn.body_params

    case :global.whereis_name(para) do
      :undefined ->
        send_resp(
          conn,
          404,
          Jason.encode!(%{
            status: "error",
            message: "Usuario #{para} no encontrado"
          })
        )

      pid ->
        Tpg.enviar(de, pid, msg)

        send_resp(
          conn,
          200,
          Jason.encode!(%{
            status: "success",
            message: "Mensaje enviado de #{de} a #{para}"
          })
        )
    end
  end

  get "/mensajes/:usuario" do
    case :global.whereis_name(usuario) do
      :undefined ->
        send_resp(
          conn,
          404,
          Jason.encode!(%{
            status: "error",
            message: "Usuario #{usuario} no encontrado"
          })
        )

      pid ->
        mensajes = Tpg.leer_mensajes(pid)

        send_resp(
          conn,
          200,
          Jason.encode!(%{
            status: "success",
            usuario: usuario,
            mensajes: mensajes
          })
        )
    end
  end

  get "/usuarios" do
    usuarios = Tpg.obtener_usuarios_activos()

    send_resp(
      conn,
      200,
      Jason.encode!(%{
        status: "success",
        usuarios: usuarios
      })
    )
  end

  # Página de prueba HTML usando vista EEx
  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, Tpg.Views.PageView.render_index())
  end

  match _ do
    send_resp(
      conn,
      404,
      Jason.encode!(%{
        status: "error",
        message: "Ruta no encontrada"
      })
    )
  end
end
