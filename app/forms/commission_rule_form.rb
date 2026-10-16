class CommissionRuleForm < BaseForm
  attribute :customer_group_id, :integer
  attribute :name, :string
  attribute :destination_type, :string
  attribute :base_type, :string
  attribute :percentage, :string
  attribute :cities, :string
  attribute :active, :boolean, default: true

  enum :destination_type, CommissionRule::DESTINATIONS
  enum :base_type, CommissionRule::BASES

  before_validation :normalize_fields

  validates :customer_group_id, :name, :destination_type, :base_type, presence: true
  validates :destination_type, inclusion: { in: CommissionRule::DESTINATIONS.map(&:to_s) }, allow_blank: true
  validates :base_type, inclusion: { in: CommissionRule::BASES.map(&:to_s) }, allow_blank: true
  validate :customer_group_must_belong_to_tenant
  validate :percentage_must_be_between_zero_and_one_hundred
  validate :foreign_rule_must_have_cities
  validate :national_rule_must_be_unique
  validate :cities_must_not_be_in_another_rule

  attr_accessor :tenant
  attr_writer :commission_rule

  delegate :id, :persisted?, to: :commission_rule

  class << self
    def for_commission_rule(commission_rule)
      form = new(
        customer_group_id: commission_rule.customer_group_id, name: commission_rule.name,
        destination_type: commission_rule.destination_type, base_type: commission_rule.base_type,
        percentage: format_percentage(commission_rule.percentage), cities: commission_rule.cities.join("\n"),
        active: commission_rule.activated?, tenant: commission_rule.tenant
      )
      form.commission_rule = commission_rule
      form
    end

    def format_percentage(percentage)
      ActiveSupport::NumberHelper.number_to_rounded(percentage, precision: 4, strip_insignificant_zeros: true,
                                                                separator: ',', delimiter: '')
    end
  end

  def commission_rule
    @commission_rule ||= tenant.commission_rules.new
  end

  def customer_groups
    tenant.customer_groups.order(:name, :id)
  end

  def city_list
    return [] unless destination_type_foreign?

    cities.to_s.lines.map(&:squish).compact_blank.uniq { |city| CustomerGroup.compact(city) }
  end

  def percentage_value
    BigDecimal(percentage.to_s.strip.tr(',', '.'))
  rescue ArgumentError
    nil
  end

  def submit
    transaction do
      commission_rule.update!(customer_group_id:, name:, destination_type:, base_type:, percentage: percentage_value,
                              cities: city_list, activated: active)
    end

    FreightExpenses::CalculateCommissionsJob.perform_later(tenant.id)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
  end

  def customer_group_must_belong_to_tenant
    return if customer_group_id.blank? || tenant.customer_groups.exists?(customer_group_id)

    errors.add(:customer_group_id, :invalid)
  end

  def percentage_must_be_between_zero_and_one_hundred
    value = percentage_value
    return if value&.positive? && value < 100

    errors.add(:percentage, :out_of_range)
  end

  def foreign_rule_must_have_cities
    return unless destination_type_foreign? && city_list.empty?

    errors.add(:cities, :blank)
  end

  def national_rule_must_be_unique
    return unless active && destination_type_national? && other_active_rules.national.exists?

    errors.add(:destination_type, :national_taken)
  end

  def cities_must_not_be_in_another_rule
    return unless active && destination_type_foreign?

    taken = city_list.select { |city| other_active_rules.foreign.any? { |rule| rule.serves_city?(city) } }
    errors.add(:cities, :taken, cities: taken.to_sentence) if taken.any?
  end

  def other_active_rules
    rules = tenant.commission_rules.activated.where(customer_group_id:)
    persisted? ? rules.where.not(id: commission_rule.id) : rules
  end
end
