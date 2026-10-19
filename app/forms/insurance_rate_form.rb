class InsuranceRateForm < BaseForm
  attribute :valid_from, :date
  attribute :insurance_percentage, :string
  attribute :iof_percentage, :string

  validates :valid_from, presence: true
  validate :insurance_percentage_must_be_in_range
  validate :iof_percentage_must_be_in_range
  validate :valid_from_must_be_unique

  attr_accessor :tenant
  attr_writer :insurance_rate

  delegate :id, :persisted?, to: :insurance_rate

  class << self
    def for_insurance_rate(insurance_rate)
      form = new(
        valid_from: insurance_rate.valid_from,
        insurance_percentage: format_percentage(insurance_rate.insurance_percentage),
        iof_percentage: format_percentage(insurance_rate.iof_percentage),
        tenant: insurance_rate.tenant,
      )
      form.insurance_rate = insurance_rate
      form
    end

    def format_percentage(percentage)
      ActiveSupport::NumberHelper.number_to_rounded(percentage, precision: 4, strip_insignificant_zeros: true,
                                                                separator: ',', delimiter: '')
    end

    def parse_percentage(value)
      text = value.to_s.strip
      text = text.delete('.').tr(',', '.') if text.include?(',')

      BigDecimal(text)
    rescue ArgumentError
      nil
    end
  end

  def insurance_rate
    @insurance_rate ||= tenant.insurance_rates.new
  end

  def insurance_percentage_value
    self.class.parse_percentage(insurance_percentage)
  end

  def iof_percentage_value
    self.class.parse_percentage(iof_percentage)
  end

  def submit
    transaction do
      insurance_rate.update!(valid_from:, insurance_percentage: insurance_percentage_value, iof_percentage: iof_percentage_value)
    end

    FreightExpenses::CalculateJob.perform_later(tenant.id)
  end

  private

  def insurance_percentage_must_be_in_range
    value = insurance_percentage_value
    return if value&.positive? && value < 100

    errors.add(:insurance_percentage, :out_of_range)
  end

  def iof_percentage_must_be_in_range
    value = iof_percentage_value
    return if value && !value.negative? && value < 100

    errors.add(:iof_percentage, :out_of_range)
  end

  def valid_from_must_be_unique
    return if valid_from.blank?

    rates = tenant.insurance_rates.where(valid_from:)
    rates = rates.where.not(id: insurance_rate.id) if persisted?
    return unless rates.exists?

    errors.add(:valid_from, :taken)
  end
end
