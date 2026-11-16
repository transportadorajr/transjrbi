class GoalFilterForm < BaseForm
  attribute :month, :string
  attribute :dimension, :string

  validate :month_must_be_a_month
  validates :dimension, inclusion: { in: Dashboard::Goals::DIMENSIONS.keys }, allow_blank: true

  def month_value
    return Date.current.beginning_of_month if month.blank?

    RevenueGoal.parse_month(month) if month.to_s.match?(/\A\d{4}-\d{2}\z/)
  end

  def dimension_value
    dimension.presence || Dashboard::Goals::DEFAULT_DIMENSION
  end

  def section
    Dashboard::Goals::DIMENSIONS.fetch(dimension_value)
  end

  def current_month?
    month_value == Date.current.beginning_of_month
  end

  private

  def month_must_be_a_month
    errors.add(:month, :invalid) unless month_value
  end
end
