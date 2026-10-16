module Atua
  class InitialLoadCommand
    MONTH_INTERVAL = 10.minutes

    class << self
      def call(tenant, start_date, production_access: false)
        new(tenant, start_date, production_access:).call
      end
    end

    def initialize(tenant, start_date, production_access: false)
      @tenant = tenant
      @start_date = start_date.to_date
      @production_access = production_access
    end

    def call
      registries = Report::REGISTRY_TYPES.filter_map { |report_type| enqueue(report_type) }

      registries + pending_months.each_with_index.flat_map do |(month_start, month_end, report_types), index|
        report_types.filter_map { |report_type| enqueue(report_type, month_start, month_end, wait: MONTH_INTERVAL * (index + 1)) }
      end
    end

    private

    attr_reader :tenant, :start_date, :production_access

    def pending_months
      Report.find(Report::MOVEMENT_TYPES.first).periods(start_date, Date.current).filter_map do |month_start, month_end|
        report_types = Report::MOVEMENT_TYPES.reject { |report_type| imported?(report_type, month_start, month_end) }

        [month_start, month_end, report_types] if report_types.any?
      end
    end

    def imported?(report_type, month_start, month_end)
      tenant.atua_imports.succeeded.exists?(report_type:, start_date: month_start, end_date: month_end)
    end

    def enqueue(report_type, month_start = nil, month_end = nil, wait: nil)
      ImportReportJob.set(wait:).perform_later(tenant.id, report_type.to_s, month_start, month_end, production_access:)
    end
  end
end
