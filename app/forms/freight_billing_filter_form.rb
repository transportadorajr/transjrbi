class FreightBillingFilterForm < BaseForm
  WEEK_START = :sunday
  PERIOD_PRESETS = %i[week last_week month last_month today].freeze
  TRUCK_GROUP_ID_FORMAT = /\A(\d+|#{TruckGroup::NONE})\z/

  attribute :start_date, :date
  attribute :end_date, :date
  attribute :dimension, :string
  attribute :plate, :string
  attribute :driver_code, :integer
  attribute :customer_group_id, :integer
  attribute :macro_region_id, :string
  attribute :truck_group_id, :string

  validates :start_date, :end_date, presence: true
  validates :dimension, inclusion: { in: Dashboard::Freight::DIMENSIONS }
  validates :truck_group_id, format: { with: TRUCK_GROUP_ID_FORMAT }, allow_blank: true
  validate :end_date_must_not_precede_start_date

  class << self
    def preset_period(preset)
      today = Date.current

      case preset
      when :week then today.all_week(WEEK_START)
      when :last_week then today.weeks_ago(1).all_week(WEEK_START)
      when :month then today.all_month
      when :last_month then today.prev_month.all_month
      when :today then today..today
      end
    end
  end

  def initialize(attributes = {})
    super

    apply_defaults
  end

  def period
    start_date..end_date
  end

  def filtered?
    dimension != Dashboard::Freight::DEFAULT_DIMENSION || period != self.class.preset_period(:week) ||
      [plate, driver_code, customer_group_id, macro_region_id, truck_group_id].any?(&:present?)
  end

  private

  def apply_defaults
    self.dimension = Dashboard::Freight::DEFAULT_DIMENSION if dimension.blank?
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
