module Atua
  class InitialLoadCommand
    MONTH_INTERVAL = 10.minutes

    class << self
      def call(tenant, start_date, end_date = nil)
        new(tenant, start_date, end_date).call
      end
    end

    def initialize(tenant, start_date, end_date = nil)
      @tenant = tenant
      @start_date = start_date.to_date
      @end_date = (end_date || Date.current).to_date
    end

    def call
      registries = Report::REGISTRY_TYPES.filter_map { |report_type| enqueue(report_type) }

      registries + pending_months.each_with_index.flat_map do |(month_start, month_end, report_types), index|
        report_types.filter_map { |report_type| enqueue(report_type, month_start, month_end, wait: MONTH_INTERVAL * (index + 1)) }
      end
    end

    private

    attr_reader :tenant, :start_date, :end_date

    def pending_months
      Report.find(Report::MOVEMENT_TYPES.first).periods(start_date, end_date).filter_map do |month_start, month_end|
        report_types = Report::MOVEMENT_TYPES.reject { |report_type| imported?(report_type, month_start, month_end) }

        [month_start, month_end, report_types] if report_types.any?
      end
    end

    def imported?(report_type, month_start, month_end)
      tenant.atua_imports.succeeded.exists?(report_type:, start_date: month_start, end_date: month_end)
    end

    def enqueue(report_type, month_start = nil, month_end = nil, wait: nil)
      ImportReportJob.set(wait:).perform_later(tenant.id, report_type.to_s, month_start, month_end)
    end
  end
end
