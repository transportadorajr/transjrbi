module Atua
  class ScheduleRegistriesJob < ApplicationJob
    queue_with_priority 1
    queue_as :atua

    def perform
      ScheduleImportsCommand.call(Report::REGISTRY_TYPES)
    end
  end
end
