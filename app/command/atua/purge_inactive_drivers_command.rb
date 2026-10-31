module Atua
  class PurgeInactiveDriversCommand
    RAW_DRIVER_COLUMNS = %w[cd_motorista nm_motorista nr_cpf_motorista nr_cnh id_whatsapp_motorista nr_telefone_motorista].freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      return 0 unless tenant.atua_transport_documents.exists?

      inactive_vehicles.update_all(
        [
          <<~SQL.squish,
            driver_code = NULL, driver_name = NULL, driver_document = NULL, driver_document_digits = NULL,
            driver_license = NULL, driver_whatsapp_at = NULL, raw_data = raw_data - ARRAY[:columns]::text[], updated_at = :now
          SQL
          { columns: RAW_DRIVER_COLUMNS, now: Time.current },
        ],
      )
    end

    private

    attr_reader :tenant

    def inactive_vehicles
      tenant.atua_vehicles.where.not(driver_code: nil).where.not(driver_code: active_codes)
    end

    def active_codes
      tenant.atua_transport_documents.active.recently_issued.where.not(driver_code: nil).distinct.pluck(:driver_code)
    end
  end
end
