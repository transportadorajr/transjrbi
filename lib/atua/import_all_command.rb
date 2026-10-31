module Atua
  class ImportAllCommand
    REPORT_TYPES = %i[customers vehicles manifests transport_documents expenses toll_vouchers].freeze

    class << self
      def call(tenant, start_date:, end_date:)
        new(tenant, start_date:, end_date:).call
      end
    end

    def initialize(tenant, start_date:, end_date:)
      @tenant = tenant
      @start_date = start_date
      @end_date = end_date
    end

    def call
      client = Client.new(Configuration.for(tenant))

      REPORT_TYPES.each_with_object([]) do |report_type, imports|
        imports.concat(ImportReportCommand.call(tenant, report_type, **period(report_type), client:))
        break imports unless client.logged_in?
      end
    end

    private

    attr_reader :tenant, :start_date, :end_date

    def period(report_type)
      Report.find(report_type).period? ? { start_date:, end_date: } : {}
    end
  end
end
