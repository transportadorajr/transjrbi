module Atua
  FEATURE = :atua_import

  class Error < StandardError
    attr_reader :status, :headers, :body_excerpt

    def initialize(message = nil, status: nil, headers: {}, body_excerpt: nil)
      super(message)
      @status = status
      @headers = headers
      @body_excerpt = body_excerpt
    end
  end

  class ConfigurationError < Error; end
  class AuthenticationError < Error; end
  class SessionError < Error; end
  class DownloadError < Error; end
  class SpreadsheetError < Error; end
  class LayoutError < Error; end
  class ConversionError < Error; end

  class << self
    def table_name_prefix
      'atua_'
    end

    def enabled?(tenant)
      Flipper.enabled?(FEATURE, tenant)
    end

    def enabled_tenants
      return Tenant.all if Flipper.enabled?(FEATURE)

      Tenant.where(id: enabled_tenant_ids)
    end

    private

    def enabled_tenant_ids
      Flipper.feature(FEATURE).actors_value.filter_map do |flipper_id|
        type, id = flipper_id.split(';', 2)
        id if type == Tenant.name
      end
    end
  end
end
