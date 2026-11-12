module Exportable
  extend ActiveSupport::Concern

  EXCLUDED_COLUMNS = %w[id tenant_id atua_import_id raw_data].freeze
  SENSITIVE_COLUMNS = %w[
    encrypted_password reset_password_token confirmation_token current_sign_in_ip last_sign_in_ip atua_device_token atua_device_hash
  ].freeze
  EXCLUDED_SUFFIXES = %w[_id _digits].freeze
  FOREIGN_KEY_SUFFIX = '_id'.freeze

  included do
    class_attribute :export_fields, instance_writer: false, default: {}
  end

  class_methods do
    def export_field(name, type = :string, &)
      self.export_fields = export_fields.merge(name.to_s => Export::Field.for(self, name, type, &))
    end

    def export_columns
      placed = []
      columns = column_names.filter_map do |name|
        field = export_fields[name.delete_suffix(FOREIGN_KEY_SUFFIX)] if name.end_with?(FOREIGN_KEY_SUFFIX)
        placed << field.name if field
        field || (Export::Column.for(self, name) unless excluded_from_export?(name))
      end

      columns + export_fields.values.reject { |field| placed.include?(field.name) }
    end

    private

    def excluded_from_export?(name)
      EXCLUDED_COLUMNS.include?(name) || SENSITIVE_COLUMNS.include?(name) || name.end_with?(*EXCLUDED_SUFFIXES) || polymorphic_types.include?(name)
    end

    def polymorphic_types
      reflect_on_all_associations(:belongs_to).select(&:polymorphic?).map { |association| association.foreign_type.to_s }
    end
  end
end
