module Discord
  class ErrorSubscriber
    THROTTLE_PERIOD = 1.hour
    SERVER_ERROR_STATUS = 500

    def report(error, handled:, severity:, context:, source: nil)
      return unless notify?(error, severity)
      return unless first_occurrence?(error)

      NotifyErrorCommand.call(error, handled:, context:, source:)
    end

    private

    def notify?(error, severity)
      severity == :error && !error.is_a?(Discord::Error) && server_error?(error)
    end

    def server_error?(error)
      ActionDispatch::ExceptionWrapper.status_code_for_exception(error.class.name) >= SERVER_ERROR_STATUS
    end

    def first_occurrence?(error)
      Rails.cache.write(throttle_key(error), true, unless_exist: true, expires_in: THROTTLE_PERIOD)
    end

    def throttle_key(error)
      "discord/error_notification/#{Digest::SHA256.hexdigest([error.class.name, error.backtrace&.first].join)}"
    end
  end
end
