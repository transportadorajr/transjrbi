module Atua
  class ScheduleMonthClosingJob < ApplicationJob
    queue_with_priority 1
    queue_as :atua

    def perform
      month = Time.zone.today.prev_month

      ScheduleImportsCommand.call(Report::MOVEMENT_TYPES, start_date: month.beginning_of_month, end_date: month.end_of_month)
    end
  end
end
