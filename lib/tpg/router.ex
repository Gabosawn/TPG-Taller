defmodule Tpg.Router do
  use Plug.Router

  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :match
  plug :dispatch

  # Iniciar sesión de usuario
  post "/login" do
    %{"usuario" => usuario} = conn.body_params

    case Tpg.loggear(usuario) do
      {:ok, pid} ->
        send_resp(conn, 200, Jason.encode!(%{
          status: "success",
          message: "Usuario #{usuario} logueado",
          pid: inspect(pid)
        }))
      {:error, reason} ->
        send_resp(conn, 400, Jason.encode!(%{
          status: "error",
          message: inspect(reason)
        }))
    end
  end

  # Desloggear
  post "/logout" do
    %{"usuario" => usuario} = conn.body_params
    case Tpg.desloggear(usuario) do
      {:ok, pid} ->
        send_resp(conn, 200, Jason.encode!(%{
          status: "success",
          message: "Usuario #{usuario} deslogueado. Hasta pronto!",
          pid: inspect(pid)
        }))
      {:error, reason} ->
        send_resp(conn, 400, Jason.encode!(%{
          status: "error",
          message: inspect(reason)
        }))
    end
  end

  # Enviar mensaje
  post "/enviar" do
    %{"de" => de, "para" => para, "mensaje" => msg} = conn.body_params

    # Buscar el PID del usuario destinatario
    case :global.whereis_name(para) do
      :undefined ->
        send_resp(conn, 404, Jason.encode!(%{
          status: "error",
          message: "Usuario #{para} no encontrado"
        }))
      pid ->
        Tpg.enviar(de, pid, msg)
        send_resp(conn, 200, Jason.encode!(%{
          status: "success",
          message: "Mensaje enviado de #{de} a #{para}"
        }))
    end
  end

  # Leer mensajes
  get "/mensajes/:usuario" do
    case :global.whereis_name(usuario) do
      :undefined ->
        send_resp(conn, 404, Jason.encode!(%{
          status: "error",
          message: "Usuario #{usuario} no encontrado"
        }))
      pid ->
        mensajes = Tpg.leer_mensajes(pid)
        send_resp(conn, 200, Jason.encode!(%{
          status: "success",
          usuario: usuario,
          mensajes: mensajes
        }))
    end
  end

  # Listar usuarios activos
  get "/usuarios" do
    usuarios = Tpg.obtener_usuarios_activos()
    send_resp(conn, 200, Jason.encode!(%{
      status: "success",
      usuarios: usuarios
    }))
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{
      status: "error",
      message: "Ruta no encontrada"
    }))
  end
end
