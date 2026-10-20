class FreightBillingFilterForm < BaseForm
  attribute :start_date, :date
  attribute :end_date, :date
  attribute :dimension, :string
  attribute :plate, :string
  attribute :customer_group_id, :integer

  validates :start_date, :end_date, presence: true
  validates :dimension, inclusion: { in: Dashboard::Freight::DIMENSIONS }
  validate :end_date_must_not_precede_start_date

  def initialize(attributes = {})
    super

    apply_defaults
  end

  def period
    start_date..end_date
  end

  private

  def apply_defaults
    self.dimension = Dashboard::Freight::DEFAULT_DIMENSION if dimension.blank?
    return if start_date || end_date

    self.start_date = Date.current.beginning_of_month
    self.end_date = Date.current.end_of_month
  end

  def end_date_must_not_precede_start_date
    return unless start_date && end_date && end_date < start_date

    errors.add(:end_date, :before_start_date)
  end
end
