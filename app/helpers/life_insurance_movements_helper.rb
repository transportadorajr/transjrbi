module LifeInsuranceMovementsHelper
  MOVEMENT_KINDS = { inclusion: :success, exclusion: :danger, change: :warning }.freeze

  def life_insurance_movement_counters(kind_counts)
    safe_join(kind_counts.map do |kind, count|
      counter_card(MOVEMENT_KINDS.fetch(kind), t(kind, scope: 'life_insurance_movements.index.counters'), count)
    end)
  end

  def life_insurance_movement_badge(movement)
    status_badge(movement.kind_name, kind: MOVEMENT_KINDS.fetch(movement.kind))
  end

  def life_insurance_movements_month_title(month)
    l(month, format: t('life_insurance_movements.index.month_format'))
  end

  def life_insurance_movements_month_path(month)
    life_insurance_movements_path(request.query_parameters.except('page', 'month').merge(month: month.strftime('%Y-%m')))
  end

  def life_insurance_movements_button
    return unless can?(:read, :life_insurances)

    link_to life_insurance_movements_path, class: 'btn btn-outline-secondary btn-round' do
      safe_join([icon(:'arrow-left-right', class: 'me-2'), t('life_insurance_movements.index.title')])
    end
  end

  def life_insurance_movements_xlsx_sheets(movements)
    LifeInsuranceMovement::COMPANY_SHEETS.map do |company_type|
      Export::Sheet.new(name: t(company_type, scope: 'life_insurance_movements.insurer.sheets'), columns: life_insurance_insurer_columns,
                        rows: movements.select { |movement| movement.company_type == company_type.to_s })
    end
  end

  private

  def life_insurance_insurer_columns
    [insurer_field(:movement, :integer, &:code),
     insurer_field(:registration) { |movement| movement.employee.legal_id },
     insurer_field(:legal_id) { |movement| employee_legal_id(movement.employee) },
     insurer_field(:name) { |movement| movement.employee.name },
     insurer_field(:born_on, :date) { |movement| movement.employee.born_on },
     insurer_field(:age, :integer, &:age),
     insurer_field(:gender) { |movement| t(movement.employee.gender_type, scope: 'life_insurance_movements.insurer.genders') },
     insurer_field(:premium, :decimal) { |movement| movement.premium.to_d },
     *LifeInsurance::COVERAGES.map { |column| insurer_field(column, :decimal) { |movement| movement.public_send(column).to_d } }]
  end

  def insurer_field(column, type = :string, &)
    xlsx_field(t(column, scope: 'life_insurance_movements.insurer.columns'), type, &)
  end
end
