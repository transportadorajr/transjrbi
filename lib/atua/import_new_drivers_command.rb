module Atua
  class ImportNewDriversCommand
    REPORT_TYPE = 'transport_documents'.freeze
    REGISTRY_TYPE = 'vehicles'.freeze

    class << self
      def call(import)
        new(import).call
      end
    end

    def initialize(import)
      @import = import
    end

    def call
      return unless import.report_type == REPORT_TYPE && Atua.enabled?(tenant)
      return if new_driver_codes.empty?

      ImportReportJob.perform_later(tenant.id, REGISTRY_TYPE)
    end

    private

    attr_reader :import

    delegate :tenant, to: :import

    def new_driver_codes
      documents = tenant.atua_transport_documents.active.not_canceled.where(import:).where.not(driver_code: nil)
      documents = documents.where(TransportDocument.arel_table[:created_at].gt(last_registry_import_at)) if last_registry_import_at

      documents.where.not(driver_code: registered_codes).where.not(driver_code: tenant.excluded_drivers.select(:code)).distinct.pluck(:driver_code)
    end

    def registered_codes
      tenant.atua_vehicles.active.where.not(driver_code: nil).where.not(driver_document: nil).select(:driver_code)
    end

    def last_registry_import_at
      return @last_registry_import_at if defined?(@last_registry_import_at)

      @last_registry_import_at = tenant.atua_imports.where(report_type: REGISTRY_TYPE).maximum(:created_at)
    end
  end
end
