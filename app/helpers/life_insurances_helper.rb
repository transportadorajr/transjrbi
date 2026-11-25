module LifeInsurancesHelper
  LIFE_INSURANCE_COUNTER_COLUMNS = 'col-12 col-md-6 col-xl-3'.freeze

  def life_insurance_counters(premium_totals, uninsured_count, deactivated_count)
    cards = [counter_card(:dark, t('life_insurances.index.insured'), premium_totals.sum(&:count), col_class: LIFE_INSURANCE_COUNTER_COLUMNS),
             counter_card(:warning, t('life_insurances.index.uninsured'), uninsured_count, col_class: LIFE_INSURANCE_COUNTER_COLUMNS),
             counter_card(:warning, t('life_insurances.index.deactivated'), deactivated_count, col_class: LIFE_INSURANCE_COUNTER_COLUMNS),
             counter_card(:primary, t('life_insurances.index.premium'), tax_money(premium_totals.sum(Money.zero, &:premium)),
                          col_class: LIFE_INSURANCE_COUNTER_COLUMNS)]
    cards += premium_totals.map do |total|
      counter_card(:primary, t('life_insurances.index.company_premium', company: total.company_name, count: total.count), tax_money(total.premium),
                   col_class: LIFE_INSURANCE_COUNTER_COLUMNS)
    end

    safe_join(cards)
  end

  def life_insurances_menu(life_insurance)
    menus = []

    menus << life_insurance_edit_menu(life_insurance) if can?(:update, :life_insurances)
    menus << life_insurance_exclusion_menu(life_insurance) if can?(:update, :life_insurances)

    menus
  end

  def life_insurance_deactivated_badge(life_insurance)
    status_badge(t('life_insurances.index.deactivated_employee'), kind: :danger) unless life_insurance.employee.activated?
  end

  def life_insurance_create_button
    create_button(t('life_insurances.index.new_life_insurance')) if can?(:create, :life_insurances)
  end

  def life_insurance_employee_status_options
    options_for_select(Employee.statuses, params[:employee_status])
  end

  def life_insurance_form_url(life_insurance_form)
    life_insurance_form.persisted? ? life_insurance_path(life_insurance_form.life_insurance) : life_insurances_path
  end

  def life_insurance_form_submit_label(life_insurance_form)
    t("helpers.submit.life_insurance.#{life_insurance_form.persisted? ? :update : :create}")
  end

  def life_insurance_employee_field(form, life_insurance_form)
    options = life_insurance_form.available_employees.map { |employee| [employee.name, employee.id] }

    if life_insurance_form.persisted?
      form.input_field :employee_id, as: :select, collection: options, disabled: true, class: 'form-select bg-light'
    else
      render 'components/select2', id: 'life_insurance_employee_select', name: "#{form.object_name}[employee_id]", options:,
                                   selected: life_insurance_form.employee_id, placeholder: t('life_insurances.form.employee_placeholder')
    end
  end

  def life_insurance_capital_changed_on_field(form, life_insurance_form)
    return unless life_insurance_form.persisted?

    content_tag :div, class: 'col-12 col-lg-4' do
      form.input :capital_changed_on, as: :date, html5: true, hint: t('life_insurances.form.capital_changed_on_hint'),
                                      input_html: { class: 'form-control' }
    end
  end

  def life_insurance_company_type_options
    options_for_select(LifeInsurancePolicy.enum_options_for_select(:company_type), params[:company_type])
  end

  def life_insurance_policies_button
    return unless can?(:read, :life_insurances)

    link_to life_insurance_policies_path, class: 'btn btn-outline-secondary btn-round' do
      concat icon(:'file-earmark-text', class: 'me-2')
      concat t('life_insurances.index.policies')
    end
  end

  def life_insurances_xlsx_sheets(life_insurances)
    columns = [xlsx_field(LifeInsurance.human_attribute_name(:employee)) { |life_insurance| life_insurance.employee.name },
               xlsx_field(LifeInsurancePolicy.human_attribute_name(:company_type)) { |life_insurance| life_insurance.life_insurance_policy.company_type_name },
               *LifeInsurance::COVERAGES.map { |coverage| xlsx_field(LifeInsurance.human_attribute_name(coverage), :money, &coverage) },
               xlsx_field(LifeInsurance.human_attribute_name(:premium), :money, &:premium),
               xlsx_field(LifeInsurance.human_attribute_name(:included_on), :date, &:included_on)]

    [Export::Sheet.new(name: t('life_insurances.index.title'), columns:, rows: life_insurances)]
  end

  def life_insurance_pdf_report(life_insurances, premium_totals)
    PdfReport.new(
      title: t('life_insurances.index.pdf.header'),
      columns: [pdf_column(LifeInsurance.human_attribute_name(:employee), '2fr'), pdf_column(LifeInsurancePolicy.human_attribute_name(:company_type)),
                *%i[capital spouse_death children_death funeral_assistance premium].map do |column|
                  pdf_column(LifeInsurance.human_attribute_name(column), align: :right)
                end],
      rows: life_insurances.map do |life_insurance|
        [life_insurance.employee.name, life_insurance.life_insurance_policy.company_type_name,
         *%i[capital spouse_death children_death funeral_assistance premium].map { |column| tax_money(life_insurance.public_send(column)) }]
      end,
      highlights: [pdf_highlight(t('life_insurances.index.insured'), premium_totals.sum(&:count)),
                   pdf_highlight(t('life_insurances.index.premium'), tax_money(premium_totals.sum(Money.zero, &:premium)))],
    )
  end

  def life_insurance_policies_menu(policy)
    menus = []

    menus << life_insurance_policy_edit_menu(policy) if can?(:update, :life_insurances)

    menus
  end

  def life_insurance_policy_rate(value)
    t('life_insurance_policies.rate', value: LifeInsurancePolicyForm.format_rate(value))
  end

  def life_insurance_policy_percentage(value)
    number_to_percentage(value, precision: 2, strip_insignificant_zeros: true)
  end

  def life_insurance_policy_create_button(available_company_types)
    return unless can?(:create, :life_insurances) && available_company_types.any?

    create_button(t('life_insurance_policies.index.new_life_insurance_policy'))
  end

  def life_insurance_policy_company_field(form, policy_form)
    form.input :company_type, as: :select, collection: policy_form.available_company_types, required: true, disabled: policy_form.persisted?,
                              include_blank: t('helpers.select.prompt'), input_html: { class: 'form-select' }
  end

  def life_insurance_policy_form_url(policy_form)
    policy_form.persisted? ? life_insurance_policy_path(policy_form.life_insurance_policy) : life_insurance_policies_path
  end

  def life_insurance_policy_form_submit_label(policy_form)
    t("helpers.submit.life_insurance_policy.#{policy_form.persisted? ? :update : :create}")
  end

  private

  def life_insurance_edit_menu(life_insurance)
    Menu.new(name: :edit, record: life_insurance, url: edit_life_insurance_path(life_insurance), icon: :pencil)
  end

  def life_insurance_exclusion_menu(life_insurance)
    Menu.new(name: :exclude, record: life_insurance, url: new_life_insurance_exclusion_path(life_insurance), icon: :'person-dash')
  end

  def life_insurance_policy_edit_menu(policy)
    Menu.new(name: :edit, record: policy, url: edit_life_insurance_policy_path(policy), icon: :pencil)
  end
end
