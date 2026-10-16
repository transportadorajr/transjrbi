module Admin
  module HttpRequests
    class PurgeExpiredCommand
      BATCH_SIZE = 1_000

      class << self
        delegate :call, to: :new
      end

      def call
        Admin::HttpRequest.expired.in_batches(of: BATCH_SIZE).delete_all
      end
    end
  end
end
