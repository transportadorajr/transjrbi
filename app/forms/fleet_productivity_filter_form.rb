class FleetProductivityFilterForm < BaseForm
  PERIOD_PRESETS = FreightBillingFilterForm::PERIOD_PRESETS

  attribute :start_date, :date
  attribute :end_date, :date
  attribute :plate, :string
  attribute :customer_group_id, :integer

  validates :start_date, :end_date, presence: true
  validate :end_date_must_not_precede_start_date

  class << self
    delegate :preset_period, to: :FreightBillingFilterForm
  end

  def initialize(attributes = {})
    super

    apply_defaults
  end

  def period
    start_date..end_date
  end

  def filtered?
    period != self.class.preset_period(:week) || [plate, customer_group_id].any?(&:present?)
  end

  def apply(empty_legs)
    filtered = empty_legs.by_trip_start(start_date).by_trip_end(end_date)
    filtered = filtered.by_plate(plate) if plate.present?
    filtered = filtered.by_customer_group(customer_group_id) if customer_group_id.present?
    filtered
  end

  private

  def apply_defaults
    return if start_date || end_date

    week = self.class.preset_period(:week)
    self.start_date = week.first
    self.end_date = week.last
  end

  def end_date_must_not_precede_start_date
    return unless start_date && end_date && end_date < start_date

    errors.add(:end_date, :before_start_date)
  end
end
