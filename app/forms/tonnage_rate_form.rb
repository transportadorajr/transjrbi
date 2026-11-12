class TonnageRateForm < BaseForm
  attribute :customer_group_id, :integer
  attribute :name, :string
  attribute :origin, :string
  attribute :valid_month, :string
  attribute :rate, :string
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :customer_group_id, :name, :origin, :valid_month, presence: true
  validate :customer_group_must_belong_to_tenant
  validate :origin_must_be_listed
  validate :valid_month_must_be_a_month
  validate :rate_must_be_positive
  validate :origin_must_be_unique_in_the_month

  attr_accessor :tenant
  attr_writer :tonnage_rate

  delegate :id, :persisted?, to: :tonnage_rate

  class << self
    def for_tonnage_rate(tonnage_rate)
      form = new(
        customer_group_id: tonnage_rate.customer_group_id, name: tonnage_rate.name, origin: tonnage_rate.origin.key,
        valid_month: tonnage_rate.valid_month.strftime('%Y-%m'), rate: format_rate(tonnage_rate.rate_cents),
        active: tonnage_rate.activated?, tenant: tonnage_rate.tenant
      )
      form.tonnage_rate = tonnage_rate
      form
    end

    def format_rate(rate_cents)
      ActiveSupport::NumberHelper.number_to_rounded(rate_cents.to_d / 100, precision: 2, separator: ',', delimiter: '.')
    end
  end

  def initialize(attributes = {})
    super
    given = attributes.keys.map(&:to_s)
    self.name = TonnageRate::DEFAULT_NAME unless given.include?('name')
    self.customer_group_id = default_customer_group&.id unless given.include?('customer_group_id')
  end

  def tonnage_rate
    @tonnage_rate ||= tenant.tonnage_rates.new
  end

  def customer_groups
    tenant.customer_groups.order(:name, :id)
  end

  def origins
    persisted? ? (TonnageRate::ORIGINS + [tonnage_rate.origin]).uniq(&:key) : TonnageRate::ORIGINS
  end

  def selected_origin
    origins.find { |item| item.key == origin }
  end

  def valid_month_value
    TonnageRate.parse_month(valid_month) if valid_month.to_s.match?(/\A\d{4}-\d{2}\z/)
  end

  def rate_cents
    (BigDecimal(rate.to_s.strip.delete('.').tr(',', '.')) * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  rescue ArgumentError
    nil
  end

  def submit
    transaction do
      tonnage_rate.update!(customer_group_id:, name:, nickname: selected_origin.nickname.presence, origin_city: selected_origin.city,
                           origin_state: selected_origin.state, valid_month: valid_month_value, rate_cents:, activated: active, copied_from: nil)
    end

    FreightExpenses::CalculateJob.perform_later(tenant.id)
  end

  def default_fields_locked?
    errors[:name].none? && errors[:customer_group_id].none?
  end

  private

  def default_customer_group
    tenant&.customer_groups&.find_by(name: TonnageRate::DEFAULT_CUSTOMER_GROUP_NAME)
  end

  def normalize_fields
    self.name = name.to_s.squish
    self.origin = origin.to_s.strip
    self.valid_month = valid_month.to_s.strip
  end

  def customer_group_must_belong_to_tenant
    return if customer_group_id.blank? || tenant.customer_groups.exists?(customer_group_id)

    errors.add(:customer_group_id, :invalid)
  end

  def origin_must_be_listed
    return if origin.blank? || selected_origin

    errors.add(:origin, :inclusion)
  end

  def valid_month_must_be_a_month
    return if valid_month.blank? || valid_month_value

    errors.add(:valid_month, :invalid)
  end

  def rate_must_be_positive
    return if rate_cents&.positive?

    errors.add(:rate, :greater_than, count: 0)
  end

  def origin_must_be_unique_in_the_month
    return unless active && valid_month_value && selected_origin

    key = TonnageRate.origin_key(selected_origin.city, selected_origin.state)
    return if other_active_rates.where(valid_month: valid_month_value).none? { |rate| rate.series_key.drop(1) == key }

    errors.add(:origin, :taken)
  end

  def other_active_rates
    rates = tenant.tonnage_rates.activated.where(customer_group_id:)
    persisted? ? rates.where.not(id: tonnage_rate.id) : rates
  end
end
