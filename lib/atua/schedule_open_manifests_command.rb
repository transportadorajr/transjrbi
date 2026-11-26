module Atua
  class ScheduleOpenManifestsCommand
    LOOKBACK_DAYS = 60
    REPORT_TYPE = 'manifests'.freeze

    class << self
      def call(today: Date.current)
        new(today:).call
      end
    end

    def initialize(today:)
      @today = today
    end

    def call
      Atua.enabled_tenants.order(:id).filter_map do |tenant|
        start_date = oldest_open_issued_on(tenant)
        next unless start_date

        ImportReportJob.perform_later(tenant.id, REPORT_TYPE, start_date, end_date)
      end
    end

    private

    attr_reader :today

    def oldest_open_issued_on(tenant)
      tenant.atua_manifests.active.opened.where(issued_on: (today - LOOKBACK_DAYS)..end_date).minimum(:issued_on)
    end

    def end_date
      today - ScheduleMovementsJob::MANIFEST_DAYS
    end
  end
end
