class LifeInsuranceMovement
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  KINDS = { inclusion: 1, exclusion: 2, change: 3 }.freeze
  COMPANY_SHEETS = %i[mme transjr mm_espinola].freeze

  attr_reader :kind, :occurred_on, :life_insurance

  delegate :employee, :life_insurance_policy, *LifeInsurance::COVERAGES, :premium, to: :life_insurance
  delegate :company_type, to: :life_insurance_policy

  class << self
    def for_month(life_insurances, month)
      dates = month_dates(month)

      life_insurances.moved_in(dates).preload(:employee, :life_insurance_policy)
        .flat_map { |life_insurance| movements_of(life_insurance, dates) }
        .sort_by { |movement| [movement.employee.name, movement.occurred_on, movement.code] }
    end

    def month_dates(month)
      Date.strptime(month.to_s, '%Y-%m').all_month
    rescue Date::Error
      Date.current.all_month
    end

    private

    def movements_of(life_insurance, dates)
      movements = []
      movements << new(:inclusion, life_insurance.included_on, life_insurance) if dates.cover?(life_insurance.included_on)
      movements << new(:change, life_insurance.capital_changed_on, life_insurance) if change_in?(life_insurance, dates)
      movements << new(:exclusion, life_insurance.excluded_on, life_insurance) if dates.cover?(life_insurance.excluded_on)
      movements
    end

    def change_in?(life_insurance, dates)
      dates.cover?(life_insurance.capital_changed_on) && !dates.cover?(life_insurance.included_on)
    end
  end

  def initialize(kind, occurred_on, life_insurance)
    @kind = kind
    @occurred_on = occurred_on
    @life_insurance = life_insurance
  end

  def code
    KINDS.fetch(kind)
  end

  def kind_name
    I18n.t(kind, scope: 'life_insurance_movements.kinds')
  end

  def age
    born_on = employee.born_on
    return if born_on.nil?

    occurred_on.year - born_on.year - (occurred_on.strftime('%m%d') < born_on.strftime('%m%d') ? 1 : 0)
  end

  def to_key
    [life_insurance.id, kind]
  end
end
