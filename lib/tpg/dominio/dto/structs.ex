defmodule Tpg.Dominio.Dto.WebSocket do
  defstruct [:usuario, :contrasenia, :operacion, :id, :server_pid]
   @type t :: %__MODULE__{usuario: String.t(), contrasenia: String.t(), operacion: String.t(), id: non_neg_integer() | nil, server_pid: pid() | nil}
end
