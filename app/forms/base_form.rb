class BaseForm
  extend EnumHelpers
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  class << self
    def model_name
      super.tap do |name|
        name.param_key = name.param_key.delete_suffix('_form')
        name.route_key = name.param_key.pluralize

        name.singular = name.param_key
        name.singular_route_key = name.param_key

        name.plural = name.route_key
      end
    end

    def enum_i18n_key
      model_name.param_key
    end

    def parse_cents(value)
      return if value.blank?

      (BigDecimal(value.to_s.strip.delete('.').tr(',', '.')) * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
    rescue ArgumentError
      nil
    end

    def parse_decimal(value)
      return if value.blank?

      BigDecimal(value.to_s.strip.delete('.').tr(',', '.'))
    rescue ArgumentError
      nil
    end

    def format_cents(cents)
      return if cents.nil?

      ActiveSupport::NumberHelper.number_to_rounded(cents.to_d / 100, precision: 2, separator: ',', delimiter: '.')
    end

    def format_decimal(value)
      return if value.nil?

      ActiveSupport::NumberHelper.number_to_rounded(value, precision: 3, separator: ',', delimiter: '.', strip_insignificant_zeros: true)
    end

    def enum(field, values)
      raise ArgumentError, "Please define #{field.inspect} attribute first" unless attribute_names.include?(field.to_s)

      define_enum_name(field)

      values.each do |value|
        define_method(:"#{field}_#{value}?") { send(field).to_s == value.to_s }
      end

      define_singleton_method(:"#{field.to_s.pluralize}") do
        values.index_with(&:to_s).stringify_keys
      end
    end
  end

  def save
    return unless valid?(persisted? ? :update : :create)

    submit

    errors.empty?
  end

  def submit
    raise NotImplementedError
  end

  def new_record?
    !persisted?
  end

  def persisted?
    false
  end

  protected

  def transaction(&)
    ActiveRecord::Base.transaction(&)
  end
end
