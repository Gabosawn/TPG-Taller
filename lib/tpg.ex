defmodule Tpg do
  use GenServer
  def init(state) do
    cond do
      is_list(state) -> {:ok, state}
      true -> {:error, "Initial state must be a list"}
    end
  end

  def handle_call(:dequeue, _from, [value | state]), do: {:reply, value, state}

  def handle_call(:dequeue, _from, []), do: {:reply, nil, []}

  def handle_call(:queue, _from, state), do: {:reply, state, state}

  def handle_cast({:enqueue, value}, state), do: {:noreply, state ++ [value]}

  def start_link(state), do: GenServer.start_link(__MODULE__, state, name: __MODULE__)

  def queue, do: GenServer.call(__MODULE__, :queue)
  def enqueue(value), do: GenServer.cast(__MODULE__, {:enqueue, value})
  def dequeue, do: GenServer.call(__MODULE__, :dequeue)

end
