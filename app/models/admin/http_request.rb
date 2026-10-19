module Admin
  class HttpRequest < ApplicationRecord
    RETENTION = 30.days
    MAX_BODY_SIZE = 1.megabyte
    INTEGRATIONS = %i[atua tomtom].freeze
    STATUS_GROUPS = %w[success redirection client_error server_error failed].freeze
    FORM_CONTENT_TYPE = 'application/x-www-form-urlencoded'.freeze
    JSON_CONTENT_TYPE = /json/

    belongs_to :tenant, optional: true
    belongs_to :atua_import, class_name: 'Atua::Import', optional: true

    enum :integration_type, INTEGRATIONS.index_with(&:to_s), validate: true

    validates :trace_id, :http_method, :url, presence: true

    scope :succeeded, -> { where(status_code: 200..399) }
    scope :failed, -> { where(status_code: 400..).or(where(status_code: nil)) }
    scope :expired, -> { where(created_at: ...RETENTION.ago) }
    scope :by_integration_type, ->(integration_type) { where(integration_type:) }
    scope :by_tenant, ->(tenant_id) { where(tenant_id:) }
    scope :by_atua_import, ->(atua_import_id) { where(atua_import_id:) }
    scope :by_url, ->(url) { where(arel_table[:url].matches("%#{sanitize_sql_like(url)}%")) }
    scope :by_status_group, ->(group) {
      case group
      when 'success' then where(status_code: 200..299)
      when 'redirection' then where(status_code: 300..399)
      when 'client_error' then where(status_code: 400..499)
      when 'server_error' then where(status_code: 500..)
      when 'failed' then where(status_code: nil)
      else all
      end
    }
    scope :by_period_start, ->(date) { parse_date(date)&.then { |day| where(created_at: day.beginning_of_day..) } || all }
    scope :by_period_end, ->(date) { parse_date(date)&.then { |day| where(created_at: ..day.end_of_day) } || all }

    class << self
      def statuses
        STATUS_GROUPS.index_by { |group| I18n.t(group, scope: 'admin.http_requests.status_groups') }
      end

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end
    end

    def chain
      self.class.where(trace_id:).order(:id)
    end

    def query_params
      query = URI.parse(url).query
      query.present? ? URI.decode_www_form(query) : []
    rescue URI::InvalidURIError, ArgumentError
      []
    end

    def request_params
      query_params + request_form_params
    end

    def request_form_params
      return [] unless request_body.present? && request_headers['content-type'].to_s.start_with?(FORM_CONTENT_TYPE)

      URI.decode_www_form(request_body)
    rescue ArgumentError
      []
    end

    def formatted_response_body
      return response_body unless response_body.present? && response_content_type.to_s.match?(JSON_CONTENT_TYPE)

      JSON.pretty_generate(JSON.parse(response_body))
    rescue JSON::ParserError
      response_body
    end
  end
end

# == Schema Information
#
# Table name: admin_http_requests
#
#  id                    :bigint           not null, primary key
#  attempt               :integer          default(1), not null
#  duration_ms           :integer
#  error_class           :string
#  error_message         :text
#  http_method           :string           not null
#  integration_type      :enum             not null
#  request_body          :text
#  request_headers       :jsonb            not null
#  response_binary       :boolean          default(FALSE), not null
#  response_body         :text
#  response_content_type :string
#  response_headers      :jsonb            not null
#  response_size         :bigint
#  response_truncated    :boolean          default(FALSE), not null
#  status_code           :integer
#  status_message        :string
#  url                   :text             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  atua_import_id        :bigint
#  tenant_id             :bigint
#  trace_id              :uuid             not null
#
# Indexes
#
#  index_admin_http_requests_on_atua_import_id    (atua_import_id)
#  index_admin_http_requests_on_created_at        (created_at)
#  index_admin_http_requests_on_integration_type  (integration_type)
#  index_admin_http_requests_on_status_code       (status_code)
#  index_admin_http_requests_on_tenant_id         (tenant_id)
#  index_admin_http_requests_on_trace_id          (trace_id)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id) ON DELETE => nullify
#
