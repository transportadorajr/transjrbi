module Admin
  class PurgeHttpRequestsJob < ApplicationJob
    queue_with_priority 1
    queue_as :default

    def perform
      HttpRequests::PurgeExpiredCommand.call
    end
  end
end
