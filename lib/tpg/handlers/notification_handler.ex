defmodule Tpg.Handlers.NotificationHandler do
  @moduledoc """
  Centraliza todos los comportamientos de reacción a notificaciones
  recibidas por el WebSocket del cliente.
  """
  require Logger

  @doc """
  Procesa una notificación y genera la respuesta apropiada para el cliente
  """

  # def handle_notification(:contacto_agregado, %{contacto: contacto, por: remitente_id}, state) do
  #
  #   respuesta = %{
  #     tipo: "contacto_agregado",
  #     contacto: %{
  #       receptor_id: contacto.receptor_id,
  #       nombre: contacto.nombre
  #     },
  #   }

  #   {:reply, Jason.encode!(respuesta), state}
  # end

  def handle_notification(:agregado_como_contacto, %{contacto: contacto, por: remitente_id}, state) do
    Logger.info("[notification handler] notificacion recibida")
    respuesta = %{
      tipo: "mensaje_bandeja",
      notificacion: %{
        receptor_id: contacto.receptor_id,
        nombre: contacto.nombre,
        mensaje: "#{contacto.nombre} te agregó como contacto"
      },
    }
    respuesta
    {:reply, {:text, Jason.encode!(respuesta)}, state}
  end

  def handle_notification(:grupo_creado, %{grupo: grupo, creador: creador_id}, state) do
    respuesta = %{
      tipo: "grupo_creado",
      grupo: %{
        id: grupo.id,
        nombre: grupo.nombre,
        miembros: grupo.miembros
      },
      creado_por: creador_id
    }

    {:reply, Jason.encode!(respuesta), state}
  end
  # Catch-all para notificaciones desconocidas
  def handle_notification(tipo, payload, state) do
    Logger.warning("[NotificationHandler] Notificación no manejada: #{inspect(tipo)}")
    {:no_reply, state}
  end
end
