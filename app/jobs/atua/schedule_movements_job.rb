module Atua
  class ScheduleMovementsJob < ApplicationJob
    queue_with_priority 1
    DEFAULT_DAYS = 1
    MANIFEST_DAYS = 7
    MANIFEST_TYPES = %i[manifests].freeze

    queue_as :atua

    def perform(days = DEFAULT_DAYS)
      schedule(Report::MOVEMENT_TYPES - MANIFEST_TYPES, days)
      schedule(MANIFEST_TYPES, [days, MANIFEST_DAYS].max)
    end

    private

    def schedule(report_types, days)
      today = Date.current

      ScheduleImportsCommand.call(report_types, start_date: today - (days - 1), end_date: today)
    end
  end
end
