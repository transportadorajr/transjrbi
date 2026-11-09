module Exportable
  extend ActiveSupport::Concern

  EXCLUDED_COLUMNS = %w[id tenant_id atua_import_id raw_data].freeze
  SENSITIVE_COLUMNS = %w[
    encrypted_password reset_password_token confirmation_token current_sign_in_ip last_sign_in_ip atua_device_token atua_device_hash
  ].freeze
  EXCLUDED_SUFFIXES = %w[_id _digits].freeze

  class_methods do
    def export_columns
      column_names.reject { |name| excluded_from_export?(name) }.map { |name| Export::Column.for(self, name) }
    end

    private

    def excluded_from_export?(name)
      EXCLUDED_COLUMNS.include?(name) || SENSITIVE_COLUMNS.include?(name) || name.end_with?(*EXCLUDED_SUFFIXES)
    end
  end
end
