module Atua
  class SaveVehiclesCommand < SaveReportCommand
    MODEL = Vehicle
    MAPPER = MapVehiclesCommand
    PREVIOUS_ATTRIBUTES = %i[owner_whatsapp_at driver_whatsapp_at high_performance_at].freeze

    def call
      super.tap do
        DiscardExcludedPlatesCommand.call(tenant)
        PurgeInactiveDriversCommand.call(tenant)
      end
    end
  end
end
