defmodule Tpg.Dominio.Dto.WebSocket do
  defstruct [:usuario, :contrasenia, :operacion, :id, :server_pid]
   @type t :: %__MODULE__{usuario: String.t(), contrasenia: String.t(), operacion: String.t(), id: non_neg_integer() | nil, server_pid: pid() | nil}
end

defmodule Tpg.Dominio.Dto.Mensaje do
  @derive {Jason.Encoder, only: [:id, :nombre, :estado, :contenido, :emisor, :fecha]}
  defstruct [:id, :nombre, :estado, :contenido, :emisor, :fecha]
   @type t :: %__MODULE__{id: non_neg_integer() | nil, nombre: String.t() | nil, estado: String.t() | nil, contenido: String.t() | nil, emisor: integer() | nil, fecha: DateTime.t() | nil}
end

defmodule Tpg.Dominio.Dto.Notificacion do
  @derive {Jason.Encoder, only: [:receptor_id, :tipo, :mensajes]}
  defstruct [:receptor_id, :tipo, :mensajes]
   @type t :: %__MODULE__{receptor_id: non_neg_integer() | nil, tipo: String.t() | nil, mensajes: list(Tpg.Dominio.Dto.Mensaje.t()) | nil}
end
