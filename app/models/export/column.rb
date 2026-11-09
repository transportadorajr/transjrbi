module Export
  class Column < Data.define(:model, :name, :type)
    MONEY_SUFFIX = '_cents'.freeze
    PERCENTAGE_SUFFIX = 'percentage'.freeze
    TYPES = {
      string: :string, text: :string, integer: :integer, decimal: :decimal, float: :decimal, date: :date, datetime: :datetime, boolean: :boolean
    }.freeze

    class << self
      def for(model, name)
        new(model:, name:, type: type_for(model, name))
      end

      private

      def type_for(model, name)
        column = model.columns_hash.fetch(name)
        return :string if model.defined_enums.key?(name) || column.try(:array?)
        return :money if name.end_with?(MONEY_SUFFIX) && column.type == :integer
        return :percentage if name.end_with?(PERCENTAGE_SUFFIX) && column.type.in?(%i[decimal float integer])

        TYPES.fetch(column.type, :string)
      end
    end

    def attribute
      name.delete_suffix(MONEY_SUFFIX)
    end

    def header
      model.human_attribute_name(attribute)
    end

    def translated?
      I18n.exists?("activerecord.attributes.#{model.model_name.i18n_key}.#{attribute}") || I18n.exists?("attributes.#{attribute}")
    end

    def to_h
      { header:, type:, format: }.compact
    end

    def value(record)
      raw = record.read_attribute(name)
      return if raw.nil?
      return I18n.t("enums.#{model.model_name.i18n_key}.#{name}.#{raw}") if model.defined_enums.key?(name)

      case type
      when :date then raw.iso8601
      when :datetime then raw.in_time_zone.iso8601
      when :string then text(raw)
      else raw
      end
    end

    private

    def format
      I18n.t('xlsx_export.formats.money', unit: I18n.t('number.currency.format.unit')) if type == :money
    end

    def text(raw)
      case raw
      when Array then raw.join(', ')
      when Hash then raw.to_json
      else raw.to_s
      end
    end
  end
end
