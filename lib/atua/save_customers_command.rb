module Atua
  class SaveCustomersCommand < SaveReportCommand
    MODEL = Customer
    MAPPER = MapCustomersCommand
    PREVIOUS_ATTRIBUTES = %i[whatsapp_at exporter_at simples_optant_at].freeze

    def call
      super.tap { CustomerGroups::AssignCommand.call(tenant) }
    end
  end
end
