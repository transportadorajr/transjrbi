module XlsxExport
  FEATURE = :xlsx_export
  LOCAL_URL = 'http://localhost:4000'.freeze

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class RequestError < Error; end

  class << self
    def enabled?(tenant)
      Flipper.enabled?(FEATURE, tenant)
    end

    def url
      configured_url || local_url || raise(ConfigurationError, I18n.t('xlsx_export.errors.missing_url'))
    end

    def token
      ENV['XLSX_EXPORT_TOKEN'].presence || Rails.application.credentials.dig(:xlsx_export, :token).presence
    end

    private

    def configured_url
      ENV['XLSX_EXPORT_URL'].presence || Rails.application.credentials.dig(:xlsx_export, :url).presence
    end

    def local_url
      LOCAL_URL if Rails.env.local?
    end
  end
end
