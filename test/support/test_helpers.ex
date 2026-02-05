defmodule Tpg.TestHelpers do
  @moduledoc """
  Helpers para testing
  """

  import ExUnit.Assertions

  alias Tpg.Dominio.Mensajeria
  alias Tpg.Dominio.Receptores

  # Contraseña válida que cumple requisitos (si es que los hay)
  @valid_password "Password123!"
  @valid_username "joaquin123"
  @doc """
  Crea un usuario de prueba con contraseña válida
  """
  def create_test_user(nombre \\ @valid_username, contrasenia \\ @valid_password) do
    attrs = %{
      nombre: nombre,
      contrasenia: contrasenia
    }

    Receptores.crear_usuario(attrs)
  end

  @doc """
  Crea un usuario de prueba con ID aleatorio para evitar conflictos
  """
  def create_random_user() do
    timestamp = System.monotonic_time(:microsecond)
    nombre = "user#{timestamp}"
    create_test_user(nombre, @valid_password)
  end

  @doc """
  Spawn de un proceso que simula un WebSocket
  Retorna {ws_pid, message_holder_pid}
  """
  def spawn_websocket_mock() do
    # Crear un agente para almacenar mensajes (más seguro que proceso)
    {:ok, msg_holder} = Agent.start_link(fn -> [] end)

    ws_pid = spawn(fn ->
      websocket_loop(msg_holder)
    end)

    ws_pid
  end

  defp websocket_loop(msg_holder) do
    receive do
      {:check_messages, from, ref} ->
        messages = Agent.get(msg_holder, & &1)
        send(from, {:messages, ref, Enum.reverse(messages)})
        websocket_loop(msg_holder)

      {:clear_messages, from, ref} ->
        Agent.update(msg_holder, fn _ -> [] end)
        send(from, {:cleared, ref})
        websocket_loop(msg_holder)

      msg ->
        # Guardar mensaje en el agente
        Agent.update(msg_holder, fn messages -> [msg | messages] end)
        websocket_loop(msg_holder)
    end
  end

  @doc """
  Verifica que un WebSocket recibió un mensaje que coincide con el patrón
  """
  def assert_receive_websocket(ws_pid, expected_pattern, timeout \\ 1000) do
    ref = make_ref()
    send(ws_pid, {:check_messages, self(), ref})

    receive do
      {:messages, ^ref, messages} ->
        matching_message = Enum.find(messages, fn msg ->
          messages_match?(msg, expected_pattern)
        end)

        case matching_message do
          nil ->
            flunk("""
            No se recibió mensaje que coincida con: #{inspect(expected_pattern)}

            Mensajes recibidos: #{inspect(messages, pretty: true)}
            """)
          msg ->
            msg
        end
    after
      timeout ->
        flunk("Timeout (#{timeout}ms) esperando mensaje en WebSocket")
    end
  end

  # Comparar mensajes con patrones
  defp messages_match?({tag, data1}, {tag, data2}) when is_atom(tag) do
    # Comparar tuplas por tag
    compare_data(data1, data2)
  end

  defp messages_match?(msg, pattern) do
    msg == pattern
  end

  defp compare_data(data1, data2) when is_map(data1) and is_map(data2) do
    # Para mapas, verificar que data2 sea un subset de data1
    Enum.all?(data2, fn {key, value} ->
      Map.has_key?(data1, key) and (value == :_ or Map.get(data1, key) == value)
    end)
  end

  defp compare_data(data1, :_), do: not is_nil(data1)
  defp compare_data(data1, data2), do: data1 == data2

  @doc """
  Limpia los mensajes del WebSocket mock
  """
  def clear_websocket_messages(ws_pid) do
    ref = make_ref()
    send(ws_pid, {:clear_messages, self(), ref})

    receive do
      {:cleared, ^ref} -> :ok
    after
      1000 -> {:error, :timeout}
    end
  end

  @doc """
  Espera a que una condición sea verdadera
  """
  def wait_until(fun, timeout \\ 5000, interval \\ 100) do
    wait_until_impl(fun, timeout, interval, System.monotonic_time(:millisecond))
  end

  defp wait_until_impl(fun, timeout, interval, start_time) do
    if fun.() do
      :ok
    else
      elapsed = System.monotonic_time(:millisecond) - start_time

      if elapsed >= timeout do
        flunk("Timeout esperando condición después de #{elapsed}ms")
      else
        Process.sleep(interval)
        wait_until_impl(fun, timeout, interval, start_time)
      end
    end
  end

  @doc """
  Obtiene los mensajes actuales de un WebSocket sin esperar
  """
  def get_websocket_messages(ws_pid) do
    ref = make_ref()
    send(ws_pid, {:check_messages, self(), ref})

    receive do
      {:messages, ^ref, messages} -> messages
    after
      500 -> []
    end
  end
end
