module RiskAssessmentsHelper
  RISK_ASSESSMENT_STATUS_KINDS = { recommended: :success, not_recommended: :danger, in_progress: :warning }.freeze

  def risk_assessments_menu(risk_assessment)
    menus = []

    menus << risk_assessment_edit_menu(risk_assessment) if can?(:update, :risk_assessments)
    menus << risk_assessment_destroy_menu(risk_assessment) if can?(:destroy, :risk_assessments)

    menus
  end

  def risk_assessment_status_badge(risk_assessment)
    return t('tax.blank') if risk_assessment.status_type.nil?

    status_badge(risk_assessment.status_type_name, kind: RISK_ASSESSMENT_STATUS_KINDS.fetch(risk_assessment.status_type.to_sym))
  end

  def risk_assessment_status_text(risk_assessment)
    risk_assessment.status_type ? risk_assessment.status_type_name : t('tax.blank')
  end

  def risk_assessment_score(risk_assessment)
    risk_assessment.score || t('tax.blank')
  end

  def risk_assessment_valid_until(risk_assessment)
    risk_assessment.valid_until ? l(risk_assessment.valid_until) : t('tax.blank')
  end

  def risk_assessment_employee_field(form, risk_assessment_form)
    if risk_assessment_form.persisted?
      form.input_field :employee_id, as: :select, collection: risk_assessment_employee_options(risk_assessment_form), disabled: true,
                                     class: 'form-select bg-light'
    else
      render 'components/select2', id: 'risk_assessment_employee_select', name: "#{form.object_name}[employee_id]",
                                   options: risk_assessment_employee_options(risk_assessment_form), selected: risk_assessment_form.employee_id,
                                   placeholder: t('risk_assessments.form.employee_placeholder')
    end
  end

  def risk_assessment_employee_options(risk_assessment_form)
    risk_assessment_form.available_employees.map { |employee| [employee.name, employee.id] }
  end

  def risk_assessment_provider_type_options(selected = params[:provider_type])
    options_for_select(RiskAssessment.enum_options_for_select(:provider_type), selected)
  end

  def risk_assessment_status_type_options(selected = params[:status_type])
    options_for_select(RiskAssessment.enum_options_for_select(:status_type), selected)
  end

  def risk_assessment_company_type_options
    options_for_select(Employee.enum_options_for_select(:company_type), params[:company_type])
  end

  def risk_assessment_form_url(risk_assessment_form)
    risk_assessment_form.persisted? ? risk_assessment_path(risk_assessment_form.risk_assessment) : risk_assessments_path
  end

  def risk_assessment_form_submit_label(risk_assessment_form)
    t("helpers.submit.risk_assessment.#{risk_assessment_form.persisted? ? :update : :create}")
  end

  def risk_assessment_create_button
    create_button(t('risk_assessments.index.new_risk_assessment')) if can?(:create, :risk_assessments)
  end

  def risk_assessment_pdf_report(risk_assessments)
    PdfReport.new(
      title: t('risk_assessments.index.pdf.header'),
      columns: [pdf_column(RiskAssessment.human_attribute_name(:employee), '2fr'), pdf_column(RiskAssessment.human_attribute_name(:provider_type)),
                pdf_column(RiskAssessment.human_attribute_name(:score), align: :right),
                pdf_column(RiskAssessment.human_attribute_name(:valid_until)), pdf_column(RiskAssessment.human_attribute_name(:status_type)),
                pdf_column(RiskAssessment.human_attribute_name(:notes), '2fr')],
      rows: risk_assessments.map do |risk_assessment|
        [risk_assessment.employee.name, risk_assessment.provider_type_name, risk_assessment_score(risk_assessment),
         risk_assessment_valid_until(risk_assessment), risk_assessment_status_text(risk_assessment), risk_assessment.notes.to_s]
      end,
    )
  end

  private

  def risk_assessment_edit_menu(risk_assessment)
    Menu.new(name: :edit, record: risk_assessment, url: edit_risk_assessment_path(risk_assessment), icon: :pencil)
  end

  def risk_assessment_destroy_menu(risk_assessment)
    Menu.new(
      name: :destroy,
      record: risk_assessment,
      url: risk_assessment_path(risk_assessment),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('risk_assessments.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
