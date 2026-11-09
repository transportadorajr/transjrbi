module XlsxExport
  FEATURE = :xlsx_export
  DEFAULT_URL = 'http://localhost:4000'.freeze

  class Error < StandardError; end
  class RequestError < Error; end

  class << self
    def enabled?(tenant)
      Flipper.enabled?(FEATURE, tenant)
    end

    def url
      ENV['XLSX_EXPORT_URL'].presence || Rails.application.credentials.dig(:xlsx_export, :url).presence || DEFAULT_URL
    end

    def token
      ENV['XLSX_EXPORT_TOKEN'].presence || Rails.application.credentials.dig(:xlsx_export, :token).presence
    end
  end
end
