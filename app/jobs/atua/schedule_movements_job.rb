module Atua
  class ScheduleMovementsJob < ApplicationJob
    queue_with_priority 1
    DEFAULT_DAYS = 10

    queue_as :atua

    def perform(days = DEFAULT_DAYS)
      today = Time.zone.today

      ScheduleImportsCommand.call(Report::MOVEMENT_TYPES, start_date: today - (days - 1), end_date: today)
    end
  end
end
