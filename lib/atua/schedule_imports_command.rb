module Atua
  class ScheduleImportsCommand
    class << self
      def call(report_types, start_date: nil, end_date: nil)
        new(report_types, start_date:, end_date:).call
      end
    end

    def initialize(report_types, start_date: nil, end_date: nil)
      @report_types = report_types
      @start_date = start_date
      @end_date = end_date
    end

    def call
      Atua.enabled_tenants.order(:id).flat_map do |tenant|
        report_types.filter_map { |report_type| ImportReportJob.perform_later(tenant.id, report_type.to_s, start_date, end_date) }
      end
    end

    private

    attr_reader :report_types, :start_date, :end_date
  end
end
