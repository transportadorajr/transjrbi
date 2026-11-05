class TripFilterForm < BaseForm
  PERIOD_PRESETS = FreightBillingFilterForm::PERIOD_PRESETS
  ID_FORMAT = /\A\d+\z/

  attribute :start_date, :date
  attribute :end_date, :date
  attribute :dimension, :string
  attribute :plate, :string
  attribute :driver_code, :integer
  attribute :truck_group_id, :string
  attribute :product_group_id, :string
  attribute :product_id, :string

  validates :start_date, :end_date, presence: true
  validates :dimension, inclusion: { in: Dashboard::Trip::DIMENSIONS }
  validates :truck_group_id, :product_group_id, :product_id, format: { with: ID_FORMAT }, allow_blank: true
  validate :end_date_must_not_precede_start_date

  class << self
    delegate :preset_period, to: FreightBillingFilterForm
  end

  delegate :preset_period, to: :class

  def initialize(attributes = {})
    super

    apply_defaults
  end

  def period
    start_date..end_date
  end

  def filtered?
    dimension != Dashboard::Trip::DEFAULT_DIMENSION || period != preset_period(:week) || [plate, driver_code, truck_group_id, product_group_id, product_id].any?(&:present?)
  end

  private

  def apply_defaults
    self.dimension = Dashboard::Trip::DEFAULT_DIMENSION if dimension.blank?
    return if start_date || end_date

    week = preset_period(:week)
    self.start_date = week.first
    self.end_date = week.last
  end

  def end_date_must_not_precede_start_date
    return unless start_date && end_date && end_date < start_date

    errors.add(:end_date, :before_start_date)
  end
end
