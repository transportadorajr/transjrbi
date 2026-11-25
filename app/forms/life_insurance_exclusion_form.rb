class LifeInsuranceExclusionForm < BaseForm
  attribute :excluded_on, :date

  validates :excluded_on, presence: true
  validate :excluded_on_must_follow_included_on

  attr_accessor :life_insurance

  def initialize(attributes = {})
    super
    self.excluded_on ||= Date.current
  end

  def persisted?
    false
  end

  def submit
    life_insurance.update!(excluded_on:)
  end

  private

  def excluded_on_must_follow_included_on
    return if excluded_on.nil? || life_insurance.included_on.nil? || excluded_on >= life_insurance.included_on

    errors.add(:excluded_on, :before_included_on)
  end
end
