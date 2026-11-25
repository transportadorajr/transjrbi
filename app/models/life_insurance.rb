class LifeInsurance < ApplicationRecord
  include Sortable

  COVERAGES = %i[capital accidental_death accidental_permanent_disability functional_permanent_disability spouse_death children_death
                 funeral_assistance].freeze

  PremiumTotal = Data.define(:company_type, :count, :premium) do
    def company_name
      LifeInsurancePolicy.human_enum_name(:company_type, company_type)
    end
  end

  sortable :employee_name, -> { sort_text(Employee.arel_table[:name]) }
  sortable :capital, -> { capital_cents_expression }
  sortable :premium, -> { premium_cents_expression }

  belongs_to :tenant
  belongs_to :employee
  belongs_to :life_insurance_policy

  delegate :funeral_assistance, to: :life_insurance_policy

  validates :capital_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :employee_id, uniqueness: { conditions: -> { where(excluded_on: nil) } }, if: -> { excluded_on.nil? }
  validate :excluded_on_must_follow_included_on
  validate :policy_must_match_company

  scope :covered_on, ->(date) {
    where(included_on: nil).or(where(included_on: ..date)).merge(where(excluded_on: nil).or(where(excluded_on: date.next_day..)))
  }
  scope :by_name, ->(name) { joins(:employee).merge(Employee.by_name(name)) }
  scope :by_company_type, ->(company_type) { joins(:employee).merge(Employee.by_company_type(company_type)) }
  scope :by_employee_status, ->(status) { joins(:employee).merge(Employee.by_status(status)) }
  scope :with_deactivated_employee, -> { joins(:employee).merge(Employee.not_activated) }
  scope :moved_in, ->(dates) { where(included_on: dates).or(where(excluded_on: dates)).or(where(capital_changed_on: dates)) }

  class << self
    def capital_cents_expression
      Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[:capital_cents], LifeInsurancePolicy.arel_table[:capital_cents]])
    end

    def premium_cents_expression
      per_mille = Arel::Nodes::Multiplication.new(capital_cents_expression, LifeInsurancePolicy.arel_table[:premium_rate_per_mille])

      Arel::Nodes::NamedFunction.new('ROUND', [Arel::Nodes::Division.new(per_mille, LifeInsurancePolicy::PER_MILLE)])
    end

    def premium_totals
      company = LifeInsurancePolicy.arel_table[:company_type]

      joins(:life_insurance_policy).reorder(nil).group(company).order(company)
        .pluck(company, Arel.star.count, premium_cents_expression.sum)
        .map { |company_type, count, cents| PremiumTotal.new(company_type:, count:, premium: Money.from_cents(cents.to_i)) }
    end
  end

  def capital_cents
    self[:capital_cents] || life_insurance_policy&.capital_cents
  end

  def capital
    Money.from_cents(capital_cents.to_i)
  end

  alias accidental_death capital
  alias accidental_permanent_disability capital
  alias functional_permanent_disability capital

  def premium
    Money.from_cents(life_insurance_policy.premium_cents(capital_cents))
  end

  def spouse_death
    Money.from_cents(life_insurance_policy.spouse_cents(capital_cents))
  end

  def children_death
    Money.from_cents(life_insurance_policy.children_cents(capital_cents))
  end

  def covered_on?(date)
    (included_on.nil? || included_on <= date) && (excluded_on.nil? || excluded_on > date)
  end

  private

  def excluded_on_must_follow_included_on
    return if included_on.nil? || excluded_on.nil? || excluded_on >= included_on

    errors.add(:excluded_on, :before_included_on)
  end

  def policy_must_match_company
    return if employee.nil? || life_insurance_policy.nil? || employee.company_type == life_insurance_policy.company_type

    errors.add(:life_insurance_policy, :other_company)
  end
end

# == Schema Information
#
# Table name: life_insurances
#
#  id                       :bigint           not null, primary key
#  capital_cents            :bigint
#  capital_changed_on       :date
#  excluded_on              :date
#  included_on              :date
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  employee_id              :bigint           not null
#  life_insurance_policy_id :bigint           not null
#  tenant_id                :bigint           not null
#
# Indexes
#
#  index_life_insurances_on_employee_id_and_included_on  (employee_id,included_on)
#  index_life_insurances_on_employee_id_not_excluded     (employee_id) UNIQUE WHERE (excluded_on IS NULL)
#  index_life_insurances_on_life_insurance_policy_id     (life_insurance_policy_id)
#  index_life_insurances_on_tenant_id                    (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (employee_id => employees.id)
#  fk_rails_...  (life_insurance_policy_id => life_insurance_policies.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
