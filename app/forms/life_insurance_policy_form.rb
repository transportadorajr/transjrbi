class LifeInsurancePolicyForm < BaseForm
  attribute :company_type, :string
  attribute :capital, :string
  attribute :premium_rate_per_mille, :string
  attribute :spouse_percentage, :string
  attribute :children_percentage, :string
  attribute :funeral_assistance, :string

  validates :company_type, :capital, :premium_rate_per_mille, :spouse_percentage, :children_percentage, :funeral_assistance, presence: true
  validates :company_type, inclusion: { in: LifeInsurancePolicy.company_types.keys }, allow_blank: true
  validate :company_type_must_be_available
  validate :capital_must_be_positive
  validate :premium_rate_must_be_in_range
  validate :percentages_must_be_in_range
  validate :funeral_assistance_must_not_be_negative

  attr_accessor :tenant
  attr_writer :life_insurance_policy

  delegate :id, :persisted?, to: :life_insurance_policy

  class << self
    def for_life_insurance_policy(policy)
      form = new(
        tenant: policy.tenant, company_type: policy.company_type, capital: format_cents(policy.capital_cents),
        premium_rate_per_mille: format_rate(policy.premium_rate_per_mille), spouse_percentage: format_rate(policy.spouse_percentage),
        children_percentage: format_rate(policy.children_percentage), funeral_assistance: format_cents(policy.funeral_assistance_cents)
      )
      form.life_insurance_policy = policy
      form
    end

    def format_rate(value)
      ActiveSupport::NumberHelper.number_to_rounded(value, precision: 4, separator: ',', delimiter: '', strip_insignificant_zeros: true)
    end
  end

  def life_insurance_policy
    @life_insurance_policy ||= tenant.life_insurance_policies.new
  end

  def available_company_types
    taken = tenant.life_insurance_policies.where.not(id: life_insurance_policy.id).pluck(:company_type)

    LifeInsurancePolicy.enum_options_for_select(:company_type, except: taken)
  end

  def submit
    life_insurance_policy.update!(
      company_type:, capital_cents: self.class.parse_cents(capital), premium_rate_per_mille: parsed(:premium_rate_per_mille),
      spouse_percentage: parsed(:spouse_percentage), children_percentage: parsed(:children_percentage),
      funeral_assistance_cents: self.class.parse_cents(funeral_assistance)
    )
  end

  private

  def parsed(attribute)
    self.class.parse_decimal(public_send(attribute))
  end

  def company_type_must_be_available
    return if company_type.blank?

    others = tenant.life_insurance_policies.where(company_type:)
    others = others.where.not(id: life_insurance_policy.id) if persisted?
    errors.add(:company_type, :taken) if others.exists?
  end

  def capital_must_be_positive
    return if capital.blank? || self.class.parse_cents(capital)&.positive?

    errors.add(:capital, :greater_than, count: 0)
  end

  def premium_rate_must_be_in_range
    return if premium_rate_per_mille.blank?

    value = parsed(:premium_rate_per_mille)
    errors.add(:premium_rate_per_mille, :out_of_range) unless value&.positive? && value < LifeInsurancePolicy::PER_MILLE
  end

  def percentages_must_be_in_range
    %i[spouse_percentage children_percentage].each do |attribute|
      next if public_send(attribute).blank?

      value = parsed(attribute)
      errors.add(attribute, :out_of_range) unless value && !value.negative? && value <= LifeInsurancePolicy::PERCENT
    end
  end

  def funeral_assistance_must_not_be_negative
    return if funeral_assistance.blank? || self.class.parse_cents(funeral_assistance)&.>=(0)

    errors.add(:funeral_assistance, :greater_than_or_equal_to, count: 0)
  end
end
