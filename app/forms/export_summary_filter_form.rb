class ExportSummaryFilterForm < BaseForm
  PERIOD_PRESETS = %i[week month last_month last_three_months].freeze
  DEFAULT_PRESET = :month
  ID_FORMAT = /\A\d+\z/

  attribute :start_date, :date
  attribute :end_date, :date
  attribute :customer_group_id, :string
  attribute :plant, :string
  attribute :country, :string
  attribute :shortcut_id, :string

  validates :start_date, :end_date, presence: true
  validates :customer_group_id, :shortcut_id, format: { with: ID_FORMAT }, allow_blank: true
  validate :end_date_must_not_precede_start_date

  class << self
    def preset_period(preset)
      today = Date.current

      case preset
      when :week then today.all_week(Dashboard::Export::WEEK_START)
      when :month then today.all_month
      when :last_month then today.prev_month.all_month
      when :last_three_months then today.months_ago(2).beginning_of_month..today.end_of_month
      end
    end
  end

  delegate :preset_period, to: :class

  def initialize(attributes = {})
    super

    apply_default_period
  end

  def period
    start_date..end_date
  end

  def dashboard_filters
    { customer_group_id:, plant:, country: }.compact_blank
  end

  def filtered?
    period != preset_period(DEFAULT_PRESET) || dashboard_filters.any? || shortcut_id.present?
  end

  private

  def apply_default_period
    return if start_date || end_date

    period = preset_period(DEFAULT_PRESET)
    self.start_date = period.first
    self.end_date = period.last
  end

  def end_date_must_not_precede_start_date
    return unless start_date && end_date && end_date < start_date

    errors.add(:end_date, :before_start_date)
  end
end
