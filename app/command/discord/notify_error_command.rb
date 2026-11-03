module Discord
  class NotifyErrorCommand
    COLOR = 0xDC3545
    TITLE_LIMIT = 256
    MESSAGE_LIMIT = 1000
    BACKTRACE_LINES = 5
    BACKTRACE_LIMIT = 1000
    CONTEXT_FIELDS = %i[tenant_id user_id admin_user_id].freeze

    class << self
      def call(error, handled:, context: {}, source: nil, client: Client.new)
        new(error, handled:, context:, source:, client:).call
      end
    end

    def initialize(error, handled:, context:, source:, client:)
      @error = error
      @handled = handled
      @context = context
      @source = source
      @client = client
    end

    def call
      client.execute_webhook(payload)
    rescue Discord::Error => e
      Rails.logger.warn(I18n.t('discord.errors.notification_failed', reason: e.message))
      nil
    end

    private

    attr_reader :error, :handled, :context, :source, :client

    def payload
      {
        username: I18n.t('discord.error_notification.username'),
        allowed_mentions: { parse: [] },
        embeds: [
          {
            title: error.class.name.truncate(TITLE_LIMIT),
            description: error.message.to_s.truncate(MESSAGE_LIMIT),
            color: COLOR,
            timestamp: Time.current.iso8601,
            fields: [*summary_fields, *context_fields, backtrace_field].compact,
          },
        ],
      }
    end

    def summary_fields
      [
        field(:environment, Rails.env),
        field(:source, source.presence || I18n.t('discord.error_notification.unknown')),
        field(:handled, I18n.t("discord.error_notification.#{handled ? 'handled_error' : 'unhandled_error'}")),
      ]
    end

    def context_fields
      CONTEXT_FIELDS.filter_map { |key| field(key, context[key]) if context[key].present? }
    end

    def backtrace_field
      lines = Rails.backtrace_cleaner.clean(Array(error.backtrace)).presence || Array(error.backtrace)
      return if lines.empty?

      { name: I18n.t('discord.error_notification.backtrace'), value: "```\n#{lines.first(BACKTRACE_LINES).join("\n").truncate(BACKTRACE_LIMIT)}\n```" }
    end

    def field(key, value)
      { name: I18n.t("discord.error_notification.#{key}"), value: value.to_s, inline: true }
    end
  end
end
