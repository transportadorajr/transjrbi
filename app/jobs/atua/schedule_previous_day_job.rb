module Atua
  class SchedulePreviousDayJob < ApplicationJob
    queue_with_priority 1
    queue_as :atua

    def perform
      yesterday = Date.current.yesterday

      ScheduleImportsCommand.call(Report::MOVEMENT_TYPES, start_date: yesterday, end_date: yesterday)
    end
  end
end
