defmodule Tpg.Handlers.NotificationHandler do
  @moduledoc """
  Centraliza todos los comportamientos de reacción a notificaciones
  recibidas por el WebSocket del cliente.
  """
  require Logger

  def handle_notification(:mensaje_nuevo, %{emisor: emisor, mensaje: mensaje }, state) do
    respuesta = %{
      tipo: "mensaje_nuevo",
      mensaje: %{
        emisor: emisor.id_receptor,
        emisor_nombre: emisor.nombre,
        contenido: mensaje.contenido,
        fecha: mensaje.fecha
      }
    }
    {:reply, {:text, Jason.encode!(respuesta)}, state}
  end

  def handle_notification(:notificacion_bandeja, %{emisor: emisor, mensaje: mensaje}, state) do

    # state.id es el id del usuario receptor
    conversacion_id = "privado-#{emisor.receptor_id}"
    respuesta = %{
      tipo: "notificacion_chat",
      notificacion: %{
        receptor_id: emisor.receptor_id,
        nombre: emisor.nombre,
        conversacion_id: conversacion_id,
        mensaje: mensaje.contenido
      }
    }

    Logger.debug(inspect(respuesta))
    {:reply, {:text, Jason.encode!(respuesta)}, state}
  end

  def handle_notification(:contacto_en_linea, %{contacto: emisor}, state) do
    conversacion_id = "privado-#{emisor.receptor_id}"
    respuesta = %{
      tipo: "contacto_en_linea",
      notificacion: %{
        receptor_id: emisor.receptor_id,
        nombre: emisor.nombre,
        conversacion_id: conversacion_id
      }
    }
    {:reply, {:text, Jason.encode!(respuesta)}, state}
  end
  def handle_notification(:saliendo_de_linea, %{contacto: emisor}, state) do
    conversacion_id = "privado-#{emisor.receptor_id}"
    respuesta = %{
      tipo: "contacto_no_en_linea",
      notificacion: %{
        receptor_id: emisor.receptor_id,
        nombre: emisor.nombre,
        conversacion_id: conversacion_id
      }
    }
    IO.inspect(respuesta)
    {:reply, {:text, Jason.encode!(respuesta)}, state}
  end
  def handle_notification(:contacto_nuevo, %{tipo: tipo, receptor_id: receptor_id, nombre: nombre}, state) do
    Logger.info("[notification handler] notificacion recibida")
    respuesta = %{
      tipo: "contacto_nuevo",
      contacto: %{
        tipo_contacto: tipo,
        receptor_id: receptor_id,
        nombre: nombre
      },
    }
    Logger.debug( IO.inspect(respuesta))
    {:reply, {:text, Jason.encode!(respuesta)}, state}
  end

  @doc """
  Notifica al cliente que fué agregado como contacto por alguien
  """
  def handle_notification(:agregado_como_contacto, %{contacto: contacto, por: remitente_id}, state) do
    Logger.info("[notification handler] notificacion recibida")
    respuesta = %{
      tipo: "notificacion_bandeja",
      notificacion: %{
        receptor_id: contacto.receptor_id,
        nombre: contacto.nombre,
        mensaje: "#{contacto.nombre} te agregó como contacto",
        conversacion_id: "privado-#{contacto.receptor_id}"
      },
    }
    {:reply, {:text, Jason.encode!(respuesta)}, state}
  end

  def handle_notification(:grupo_creado, %{grupo: grupo, creador: creador}, state) do
    respuesta = %{
      tipo: "notificacion_bandeja",
      notificacion: %{
        receptor_id: grupo.id,
        nombre: creador.nombre,
        mensaje: "#{creador.nombre} te agregó a un nuevo grupo",
        conversacion_id: "grupo-#{grupo.id}"
      }
    }
    {:reply, {:text, Jason.encode!(respuesta)}, state}
  end

  def handle_notification(:chat_abierto, %{receptor: receptor, mensajes: mensajes}, state) do

    respuesta = %{
      tipo: "chat_abierto",
      chat: Map.take(receptor, [:receptor_id, :nombre, :ultima_conexion, :descripcion, :tipo, :en_linea]),
      mensajes: mensajes,
      receptor: state.id,
    }
    {:reply, {:text, Jason.encode!(respuesta)}, state}
  end

  # Catch-all para notificaciones desconocidas
  def handle_notification(tipo, payload, state) do
    Logger.warning("[NotificationHandler] Notificación no manejada: #{inspect(tipo)}")
    IO.inspect(payload)
    {:ok, state}
  end

  def notificar(:error, mensaje, state) do
    mensaje_error =
      Jason.encode!(%{
        tipo: "error",
        mensaje: "#{mensaje}"
      })
    {:reply, {:text, mensaje_error}, state}
  end
  def notificar(:bienvenida, usuario, state) do
    mensaje_bienvenida =
      Jason.encode!(%{
        tipo: "bienvenida",
        mensaje: "Conectado como #{usuario}",
        timestamp: DateTime.utc_now()
      })
    {:reply, {:text, mensaje_bienvenida}, state}
  end
  def notificar(:sistema, mensaje, state) do
    mensaje_retorno =
      Jason.encode!(%{
        tipo: "sistema",
        mensaje: "#{mensaje}",
        timestamp: DateTime.utc_now()
      })
    {:reply, {:text, mensaje_retorno}, state}
  end
end
