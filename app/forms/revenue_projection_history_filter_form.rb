class RevenueProjectionHistoryFilterForm < BaseForm
  PERIOD_PRESETS = FreightBillingFilterForm::PERIOD_PRESETS
  DEFAULT_PRESET = :month
  SNAPSHOT_PERIOD_TYPES = %w[month week].freeze
  CUT_ATTRIBUTES = FreightDocumentFilters::FILTER_PARAMS

  attribute :start_date, :date
  attribute :end_date, :date
  attribute :period, :string
  attribute :start, :date
  attribute :plate, :string
  attribute :driver_code, :integer
  attribute :customer_group_id, :integer
  attribute :product_group_id, :integer
  attribute :product_id, :integer
  attribute :macro_region_id, :string
  attribute :truck_group_id, :string

  validates :start_date, :end_date, presence: true
  validates :truck_group_id, format: { with: FreightBillingFilterForm::TRUCK_GROUP_ID_FORMAT }, allow_blank: true
  validate :end_date_must_not_precede_start_date

  class << self
    delegate :preset_period, to: FreightBillingFilterForm

    def snapshot_period(period_type, start)
      period_type.to_s == 'week' ? start.all_week(RevenueProjections::CalculateCommand::WEEK_START) : start.all_month
    end
  end

  def initialize(attributes = {})
    super

    apply_defaults
  end

  def date_range
    start_date..end_date
  end

  def period_type
    return 'today' if date_range == self.class.preset_period(:today)
    return 'month' if date_range == start_date.all_month
    return 'week' if date_range == self.class.snapshot_period(:week, start_date)

    'range'
  end

  def preset
    PERIOD_PRESETS.find { self.class.preset_period(it) == date_range }
  end

  def cut?
    cut_params.any?
  end

  def cut_params
    CUT_ATTRIBUTES.index_with { public_send(it) }.compact_blank
  end

  def filtered?
    date_range != self.class.preset_period(DEFAULT_PRESET) || cut?
  end

  def query_params
    { start_date:, end_date:, **cut_params }
  end

  private

  def apply_defaults
    apply_snapshot_period if start && SNAPSHOT_PERIOD_TYPES.include?(period)
    return if start_date || end_date

    period = self.class.preset_period(DEFAULT_PRESET)
    self.start_date = period.first
    self.end_date = period.last
  end

  def apply_snapshot_period
    period = self.class.snapshot_period(self.period, start)
    self.start_date = period.first
    self.end_date = period.last
  end

  def end_date_must_not_precede_start_date
    return unless start_date && end_date && end_date < start_date

    errors.add(:end_date, :before_start_date)
  end
end
