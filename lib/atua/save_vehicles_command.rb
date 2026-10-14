module Atua
  class SaveVehiclesCommand < SaveReportCommand
    MODEL = Vehicle
    MAPPER = MapVehiclesCommand
    PREVIOUS_ATTRIBUTES = %i[owner_whatsapp_at driver_whatsapp_at high_performance_at].freeze
  end
end
