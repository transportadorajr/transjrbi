module Atua
  class PurgeExpiredFilesJob < ApplicationJob
    queue_with_priority 1
    queue_as :default

    def perform
      PurgeExpiredFilesCommand.call
    end
  end
end
