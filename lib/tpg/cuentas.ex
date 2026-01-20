defmodule Tpg.Cuentas do
  @moduledoc """
  Contexto para gestionar usuarios y su receptor asociado.
  """

  import Ecto.Query
  alias Tpg.Repo
  alias Ecto.Multi

  def crear_usuario(attrs) do
    Multi.new()
    |> Multi.insert(:receptor, %Tpg.Receptor{})
    |> Multi.insert(:usuario, fn %{receptor: receptor} ->
      Tpg.Usuario.changeset(%Tpg.Usuario{}, Map.put(attrs, :receptor_id, receptor.id))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{usuario: usuario}} -> {:ok, usuario}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  def crear_grupo(attrs) do
    Multi.new()
    |> Multi.insert(:receptor, %Tpg.Receptor{})
    |> Multi.insert(:grupo, fn %{receptor: receptor} ->
      Tpg.Grupo.changeset(%Tpg.Grupo{}, Map.put(attrs, :receptor_id, receptor.id))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{grupo: grupo}} -> {:ok, grupo}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end
end
