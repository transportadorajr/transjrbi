module VacationsHelper
  def vacations_menu(vacation)
    menus = []

    menus << vacation_edit_menu(vacation) if can?(:update, :vacations)
    menus << vacation_destroy_menu(vacation) if can?(:destroy, :vacations)

    menus
  end

  def vacation_period_text(first, last)
    t('vacations.period', start: l(first), finish: l(last))
  end

  def vacation_acquisition_text(vacation)
    period = vacation.period
    vacation_period_text(period.start_on, period.end_on)
  end

  def vacation_employee_field(form, vacation_form)
    if vacation_form.persisted?
      form.input_field :employee_id, as: :select, collection: vacation_employee_options(vacation_form), disabled: true,
                                     class: 'form-select bg-light'
    else
      render 'components/select2', id: 'vacation_employee_select', name: "#{form.object_name}[employee_id]",
                                   options: vacation_employee_options(vacation_form), selected: vacation_form.employee_id,
                                   placeholder: t('vacations.form.employee_placeholder')
    end
  end

  def vacation_employee_options(vacation_form)
    vacation_form.available_employees.map { |employee| [employee.name, employee.id] }
  end

  def vacation_company_type_options
    options_for_select(Employee.enum_options_for_select(:company_type), params[:company_type])
  end

  def vacation_form_url(vacation_form)
    vacation_form.persisted? ? vacation_path(vacation_form.vacation) : vacations_path
  end

  def vacation_form_submit_label(vacation_form)
    t("helpers.submit.vacation.#{vacation_form.persisted? ? :update : :create}")
  end

  def vacation_create_button
    create_button(t('vacations.index.new_vacation')) if can?(:create, :vacations)
  end

  def vacation_pdf_report(vacations)
    PdfReport.new(
      title: t('vacations.index.pdf.header'),
      columns: [pdf_column(Vacation.human_attribute_name(:employee), '2fr'), pdf_column(Vacation.human_attribute_name(:start_on)),
                pdf_column(Vacation.human_attribute_name(:end_on)), pdf_column(Vacation.human_attribute_name(:returns_on)),
                pdf_column(Vacation.human_attribute_name(:days_count), align: :right),
                pdf_column(Vacation.human_attribute_name(:sold_days), align: :right),
                pdf_column(Vacation.human_attribute_name(:acquisition_start_on)), pdf_column(Vacation.human_attribute_name(:notes), '2fr')],
      rows: vacations.map do |vacation|
        [vacation.employee.name, l(vacation.start_on), l(vacation.end_on), l(vacation.returns_on), vacation.days_count, vacation.sold_days,
         vacation_acquisition_text(vacation), vacation.notes.to_s]
      end,
    )
  end

  private

  def vacation_edit_menu(vacation)
    Menu.new(name: :edit, record: vacation, url: edit_vacation_path(vacation), icon: :pencil)
  end

  def vacation_destroy_menu(vacation)
    Menu.new(
      name: :destroy,
      record: vacation,
      url: vacation_path(vacation),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('vacations.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
