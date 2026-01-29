defmodule Tpg.ManejoMensajes do

  def obtener_contactos(state) do
    contactos = Tpg.Services.ChatService.obtener_conversaciones(state.id)

    respuesta = %{
      tipo: "contactos",
      contactos: contactos
    }

    {:reply, {:text, respuesta}, state}
  end

  def obtener_notificaciones(state) do
    notificaciones = Tpg.Services.NotificationService.obtener_notificaciones(state.id)
    respuesta = %{
      tipo: "notificaciones",
      notificaciones: notificaciones
    }
    {:reply, {:text, respuesta}, state}
  end

end
