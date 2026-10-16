module Admin
  module HttpRequests
    class RecordCommand
      FILTERED = '[FILTERED]'.freeze
      COOKIE_HEADERS = %w[cookie set-cookie].freeze
      TEXT_CONTENT_TYPE = %r{\Atext/|json|xml|javascript|x-www-form-urlencoded}

      class << self
        def call(integration_type, http_request, trace_id: nil, attempt: 1, secrets: [], &)
          new(integration_type, http_request, trace_id:, attempt:, secrets:).call(&)
        end
      end

      def initialize(integration_type, http_request, trace_id: nil, attempt: 1, secrets: [])
        @integration_type = integration_type
        @http_request = http_request
        @trace_id = trace_id || SecureRandom.uuid
        @attempt = attempt
        @secrets = Array(secrets).compact_blank.flat_map { |secret| [secret, CGI.escape(secret), ERB::Util.url_encode(secret)] }.uniq
      end

      def call
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = yield
        save(started_at, response:)

        response
      rescue StandardError => e
        save(started_at, error: e)
        raise
      end

      private

      attr_reader :integration_type, :http_request, :trace_id, :attempt, :secrets

      def save(started_at, response: nil, error: nil)
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

        Admin::HttpRequest.create!(**request_attributes, **response_attributes(response), **error_attributes(error), duration_ms:)
      rescue StandardError => e
        Rails.logger.error("[HttpRequests] could not record #{http_request.method} #{http_request.uri&.path}: #{e.class.name} #{e.message}")
      end

      def request_attributes
        atua_import = Current.atua_import

        {
          integration_type:, trace_id:, attempt:, atua_import:, tenant_id: atua_import&.tenant_id,
          http_method: http_request.method, url: filter(http_request.uri.to_s),
          request_headers: headers(http_request.to_hash), request_body: text(http_request.body)
        }
      end

      def response_attributes(response)
        return {} unless response

        body = response.body.to_s.b
        binary = binary?(body, response['content-type'])

        {
          status_code: response.code.to_i, status_message: response.message.to_s.strip.presence,
          response_headers: headers(response.to_hash), response_content_type: response['content-type'],
          response_size: body.bytesize, response_binary: binary, response_truncated: !binary && body.bytesize > Admin::HttpRequest::MAX_BODY_SIZE,
          response_body: binary ? nil : text(body)
        }
      end

      def error_attributes(error)
        return {} unless error

        { error_class: error.class.name, error_message: filter(error.message) }
      end

      def headers(hash)
        hash.to_h do |name, values|
          values = Array(values).map { |value| COOKIE_HEADERS.include?(name) ? mask_cookie(value) : filter(value) }
          [name, values.join(name == 'set-cookie' ? "\n" : ', ')]
        end
      end

      def mask_cookie(value)
        value.gsub(/(\A|;\s*)([^=;\s]+)=([^;]*)/) do
          prefix = Regexp.last_match(1)
          name = Regexp.last_match(2)
          cookie_attribute?(prefix, name) ? Regexp.last_match(0) : "#{prefix}#{name}=#{FILTERED}"
        end
      end

      def cookie_attribute?(prefix, name)
        prefix.present? && %w[path domain expires max-age samesite].include?(name.downcase)
      end

      def binary?(body, content_type)
        return false if body.empty?

        body.include?("\x00".b) || (content_type.present? && !content_type.match?(TEXT_CONTENT_TYPE))
      end

      def text(body)
        return if body.blank?

        content = body.to_s.b
        decoded = content.dup.force_encoding(Encoding::UTF_8)
        decoded = content.dup.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8) unless decoded.valid_encoding?

        filter(decoded.byteslice(0, Admin::HttpRequest::MAX_BODY_SIZE).scrub('').delete("\u0000"))
      end

      def filter(value)
        secrets.reduce(value.to_s) { |filtered, secret| filtered.gsub(secret, FILTERED) }
      end
    end
  end
end
