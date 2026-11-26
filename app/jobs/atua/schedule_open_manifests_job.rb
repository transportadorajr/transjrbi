module Atua
  class ScheduleOpenManifestsJob < ApplicationJob
    queue_with_priority 1
    queue_as :atua

    def perform
      ScheduleOpenManifestsCommand.call
    end
  end
end
