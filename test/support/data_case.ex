defmodule Tpg.DataCase do
  @moduledoc """
  Este módulo define la configuración para pruebas que requieren
  acceso a la base de datos.

  Uso:

      use Tpg.DataCase

  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Tpg.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Tpg.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Tpg.Repo, shared: not tags[:async])
    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
      Supervisor.which_children(Tpg.DynamicSupervisor)
      |> Enum.each(fn {_, pid, _, _} ->
        if is_pid(pid), do: DynamicSupervisor.terminate_child(Tpg.DynamicSupervisor, pid)
      end)
    end)
    :ok
  end
end
