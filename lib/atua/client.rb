require 'net/http'
require 'nokogiri'

module Atua
  class Client
    USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36'.freeze
    LOGIN_PAGE_PATH = 'login.php?f_popup=true'.freeze
    LOGIN_PATH = 'login.php'.freeze
    INDEX_PATH = 'index.php'.freeze
    USERNAME_FIELD = 'f_ds_apelido'.freeze
    PASSWORD_FIELD = 'f_ds_senha'.freeze
    DEVICE_HASH_FIELD = 'f_id_hash_aplicativo'.freeze
    DEVICE_HASH_COOKIE = 'id_hash_aplicativo'.freeze
    AJAX_PATH = 'lib/jaguar/AjaxIframe.php'.freeze
    AJAX_ACCEPT = 'application/json, text/javascript, */*; q=0.01'.freeze
    DEVICE_VERIFICATION_TYPE = 2
    DEVICE_VERIFICATION_PATTERN = /validarAutenticacaoUsuario\(\s*'#{DEVICE_VERIFICATION_TYPE}'\s*\)/
    PERSON_PATTERN = /cdPessoa:\s*'(\d+)'/
    EMAIL_PATTERN = /var\s+dsEmail\s*=\s*'([^']*)'/
    MASKED_EMAIL_PATTERN = /var\s+dsEmailProtegido\s*=\s*'([^']*)'/
    BUTTON_PATTERN = /name=["'](submete\d+)["']/
    DEVICE_COOKIE_PATTERN = /\Ac_ds_dispositivo_/
    XLS_SIGNATURE = "\xD0\xCF\x11\xE0".b.freeze
    XLS_EXTENSION = '.xls'.freeze
    MAX_ATTEMPTS = 3
    RETRY_BASE_DELAY = 5
    REQUEST_INTERVAL = 2
    OPEN_TIMEOUT = 15
    READ_TIMEOUT = 300
    MAX_REDIRECTS = 5
    BODY_EXCERPT_LENGTH = 500
    FILTERED = '[FILTERED]'.freeze
    RELEVANT_HEADERS = %w[content-type content-length content-disposition location server date cf-ray cf-cache-status retry-after].freeze
    NETWORK_ERRORS = [
      Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
      Errno::ETIMEDOUT, Errno::EPIPE, EOFError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse
    ].freeze

    class ServerError < StandardError
      attr_reader :response

      def initialize(response)
        super("HTTP #{response.code}")
        @response = response
      end
    end

    class SessionExpired < StandardError; end

    Device = Data.define(:device_hash, :device_cookie)
    DeviceVerification = Data.define(:person_id, :email, :masked_email, :form_fields)

    delegate :source_type, to: :configuration

    def initialize(configuration, retries: true, logger: Rails.logger)
      @configuration = configuration
      @max_attempts = retries ? MAX_ATTEMPTS : 1
      @logger = logger
      @cookies = {}
      @logged_in = false
      @requests = 0

      seed_device_cookies
    end

    def logged_in?
      @logged_in
    end

    def device_cookie
      cookies.find { |name, _| name.match?(DEVICE_COOKIE_PATTERN) }&.then { |name, value| "#{name}=#{value}" }
    end

    def login
      return if logged_in?

      form_page = request(:get, LOGIN_PAGE_PATH, failure: SessionError)
      response = request(:post, LOGIN_PATH, form: login_params(form_page), headers: post_headers(LOGIN_PAGE_PATH), retryable: false, failure: SessionError)

      raise AuthenticationError.new(I18n.t('atua.errors.login_status', status: response.code), **diagnostics(response)) unless response.code == '200'

      ensure_logged_in(response)
    end

    def request_device_code
      login
      nil
    rescue DeviceVerificationError
      verification = @device_verification
      ajax('UsuarioAutenticacao', 'enviarCodigoValidacao',
           cdPessoa: verification.person_id, idTipoModal: DEVICE_VERIFICATION_TYPE, dsDadoAutenticacao: verification.email)

      device_verification_state
    end

    def confirm_device(state, code)
      restore_device_verification(state)
      device_hash = ajax('UsuarioAutenticacaoLogin', 'validarCodigo',
                         cdPessoa: state.fetch('person_id'), idTipo: DEVICE_VERIFICATION_TYPE,
                         nrVerificacao: code.to_s.strip.upcase, dsHashAplicativo: configuration.device_hash.to_s)['dsHashAplicativo']
      raise DeviceVerificationError, I18n.t('atua.errors.device_hash_missing') if device_hash.blank?

      cookies[DEVICE_HASH_COOKIE] = device_hash
      form = state.fetch('form_fields').merge(USERNAME_FIELD => configuration.username, PASSWORD_FIELD => configuration.password, DEVICE_HASH_FIELD => device_hash)
      response = request(:post, LOGIN_PATH, form:, headers: post_headers(LOGIN_PAGE_PATH), retryable: false, failure: SessionError)
      ensure_logged_in(response)

      Device.new(device_hash:, device_cookie:)
    end

    def download(report_type, start_date: nil, end_date: nil)
      report = Report.find(report_type)

      report.periods(start_date, end_date).map do |period_start, period_end|
        download_period(report, period_start, period_end).tap { |download| yield download if block_given? }
      end
    end

    def inspect
      "#<#{self.class.name} configuration=#{configuration.inspect} logged_in=#{logged_in?}>"
    end

    private

    attr_reader :configuration, :max_attempts, :logger, :cookies

    def download_period(report, start_date, end_date)
      with_session do
        button = report.form? ? submit_button(report) : nil
        params = report.form_params(start_date:, end_date:, button:)
        response = request(:post, report.endpoint, form: params, headers: post_headers(report.endpoint))

        build_download(report, response, start_date, end_date)
      end
    end

    def with_session
      relogged = false

      begin
        login
        yield
      rescue SessionExpired
        raise SessionError, I18n.t('atua.errors.session_expired') if relogged

        relogged = true
        reset_session
        retry
      end
    end

    def reset_session
      @logged_in = false
      cookies.clear
      seed_device_cookies
    end

    def ensure_logged_in(response)
      if device_verification_page?(response)
        @device_verification = device_verification(response.body)
        raise DeviceVerificationError.new(I18n.t('atua.errors.device_verification'), **diagnostics(response))
      end
      raise AuthenticationError.new(I18n.t('atua.errors.invalid_credentials'), **diagnostics(response)) if login_form?(response)

      @logged_in = true
    end

    def device_verification_page?(response)
      response.body.to_s.b.match?(DEVICE_VERIFICATION_PATTERN)
    end

    def device_verification(html)
      text = document(html).css('script:not([src])').map(&:text).join("\n")

      DeviceVerification.new(
        person_id: text[PERSON_PATTERN, 1],
        email: text[EMAIL_PATTERN, 1],
        masked_email: text[MASKED_EMAIL_PATTERN, 1],
        form_fields: form_fields(html, scope: PASSWORD_FIELD).except(PASSWORD_FIELD),
      )
    end

    def device_verification_state
      verification = @device_verification

      {
        'cookies' => cookies.dup, 'person_id' => verification.person_id,
        'masked_email' => verification.masked_email, 'form_fields' => verification.form_fields
      }
    end

    def restore_device_verification(state)
      cookies.replace(state.fetch('cookies'))
      @logged_in = false
    end

    def ajax(klass, action, params)
      query = URI.encode_www_form([['c', klass], ['a', action], *params.map { |name, value| ["p[#{name}]", value] }])
      response = request(:get, "#{AJAX_PATH}?#{query}", headers: { 'Accept' => AJAX_ACCEPT, 'X-Requested-With' => 'XMLHttpRequest', 'Referer' => url(LOGIN_PATH) },
                                                        retryable: false, failure: AuthenticationError)
      result = JSON.parse(response.body.to_s)
      raise DeviceVerificationError.new(result['erro'].to_s, **diagnostics(response)) if result.is_a?(Hash) && result['erro'].present?

      result.is_a?(Hash) ? result : {}
    rescue JSON::ParserError
      raise AuthenticationError.new(I18n.t('atua.errors.unexpected_ajax_response', action:), **diagnostics(response))
    end

    def submit_button(report)
      response = request(:get, report.endpoint, headers: { 'Referer' => url(INDEX_PATH) })
      raise SessionExpired if login_form?(response)

      response.body.to_s[BUTTON_PATTERN, 1] || report.submit_button
    end

    def build_download(report, response, start_date, end_date)
      body = response.body.to_s.b

      unless response.code == '200' && body.start_with?(XLS_SIGNATURE)
        raise SessionExpired if login_form?(response)

        raise DownloadError.new(
          I18n.t('atua.errors.unexpected_content', report: report.type, status: response.code, content_type: response['content-type'].to_s, excerpt: excerpt(response)),
          **diagnostics(response),
        )
      end

      Download.new(
        report_type: report.type,
        start_date:,
        end_date:,
        content: body,
        content_type: response['content-type'],
        filename: suggested_filename(report, response, start_date, end_date),
      )
    end

    def request(method, path, form: nil, headers: {}, retryable: true, failure: DownloadError)
      attempts = retryable ? max_attempts : 1
      attempt = 0

      begin
        attempt += 1
        throttle
        response = perform(method, URI.parse(url(path)), form, headers, attempt:)
        raise ServerError, response if response.code.to_i >= 500

        response
      rescue ServerError, *NETWORK_ERRORS => e
        log_failure(method, path, e, attempt)

        if attempt < attempts
          pause(RETRY_BASE_DELAY * (2**(attempt - 1)))
          retry
        end

        raise_request_failure(failure, path, e, attempt)
      end
    end

    def perform(method, uri, form, headers, attempt:, trace_id: SecureRandom.uuid, redirects: 0)
      http_request = build_request(method, uri, form, headers)
      response = Admin::HttpRequests::RecordCommand.call(:atua, http_request, trace_id:, attempt:, secrets: [configuration.password]) do
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, write_timeout: OPEN_TIMEOUT) do |http|
          http.request(http_request)
        end
      end

      store_cookies(response)
      logger.info("[Atua] #{method.upcase} #{uri.path} -> #{response.code} (#{response.body.to_s.bytesize} bytes)")

      return response unless response.is_a?(Net::HTTPRedirection) && response['location'].present?
      raise DownloadError.new(I18n.t('atua.errors.too_many_redirects'), **diagnostics(response)) if redirects >= MAX_REDIRECTS

      keep_method = %w[307 308].include?(response.code)
      perform(keep_method ? method : :get, uri + response['location'], keep_method ? form : nil, headers.except('Origin'), attempt:, trace_id:, redirects: redirects + 1)
    end

    def build_request(method, uri, form, headers)
      http_request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      http_request['User-Agent'] = USER_AGENT
      http_request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      http_request['Cookie'] = cookies.map { |name, value| "#{name}=#{value}" }.join('; ') if cookies.any?
      headers.each { |name, value| http_request[name] = value }
      http_request.set_form_data(form) if form

      http_request
    end

    def seed_device_cookies
      cookies[DEVICE_HASH_COOKIE] = configuration.device_hash if configuration.device_hash.present?

      pair = configuration.device_cookie
      return if pair.blank?

      name, value = pair.split('=', 2).map(&:strip)
      cookies[name] = value if name.match?(DEVICE_COOKIE_PATTERN) && value.present?
    end

    def store_cookies(response)
      Array(response.get_fields('set-cookie')).each do |set_cookie|
        name, value = set_cookie.split(';', 2).first.split('=', 2).map(&:strip)
        next if name.blank?

        expired = value.blank? || value == 'deleted' || set_cookie.match?(/max-age=0(;|\z)/i)
        expired ? cookies.delete(name) : cookies[name] = value
      end
    end

    def throttle
      pause(REQUEST_INTERVAL) if @requests.positive?
      @requests += 1
    end

    def pause(seconds)
      sleep(seconds)
    end

    def login_params(form_page)
      params = form_fields(form_page.body, scope: PASSWORD_FIELD)
        .merge(USERNAME_FIELD => configuration.username, PASSWORD_FIELD => configuration.password)
      params[DEVICE_HASH_FIELD] = configuration.device_hash if configuration.device_hash.present? && params.key?(DEVICE_HASH_FIELD)
      params
    end

    def form_fields(html, scope:)
      doc = document(html)
      anchor = doc.at_css("[name='#{scope}']")
      form = anchor&.ancestors('form')&.first || doc

      form.css('input[name], select[name], textarea[name]').each_with_object({}) do |node, params|
        next if %w[button image reset].include?(node['type'])

        params[node['name']] = node['value'].to_s
      end
    end

    def document(html)
      text = html.to_s.b.force_encoding(Encoding::UTF_8)
      text = text.encode(Encoding::UTF_8, Encoding::ISO_8859_1) unless text.valid_encoding?

      Nokogiri::HTML(text)
    end

    def post_headers(referer_path)
      { 'Origin' => configuration.origin, 'Referer' => url(referer_path) }
    end

    def url(path)
      "#{configuration.base_url}/#{path}"
    end

    def login_form?(response)
      document(response.body).at_css("input[name='#{PASSWORD_FIELD}']").present?
    end

    def suggested_filename(report, response, start_date, end_date)
      disposition = response['content-disposition'].to_s
      filename = disposition[/filename\*=(?:UTF-8'')?([^;]+)/i, 1] || disposition[/filename="?([^";]+)"?/i, 1]
      return File.basename(CGI.unescape(filename.strip)) if filename.present?

      [report.type, start_date&.strftime('%Y%m%d'), end_date&.strftime('%Y%m%d') || Date.current.strftime('%Y%m%d')].compact.uniq.join('_') + XLS_EXTENSION
    end

    def raise_request_failure(failure, path, error, attempts)
      response = error.respond_to?(:response) ? error.response : nil
      reason = response ? "HTTP #{response.code}" : error.class.name
      message = I18n.t('atua.errors.request_failed', path: path.split('?').first, reason:, attempts:)
      message = [message, excerpt(response)].join(' ') if response

      raise failure.new(message, **(response ? diagnostics(response) : {}))
    end

    def log_failure(method, path, error, attempt)
      logger.warn("[Atua] #{method.upcase} #{path.split('?').first} failed (attempt #{attempt}/#{max_attempts}): #{error.class.name} #{error.message}")
    end

    def diagnostics(response)
      headers = response.to_hash.slice(*RELEVANT_HEADERS).transform_values { |values| values.join(', ') }

      { status: response.code.to_i, headers:, body_excerpt: excerpt(response) }
    end

    def excerpt(response)
      text = response.body.to_s.dup.force_encoding(Encoding::UTF_8)
      text = text.encode(Encoding::UTF_8, Encoding::ISO_8859_1) unless text.valid_encoding?
      text = text.squish.first(BODY_EXCERPT_LENGTH)

      configuration.password.present? ? text.gsub(configuration.password, FILTERED) : text
    end
  end
end
