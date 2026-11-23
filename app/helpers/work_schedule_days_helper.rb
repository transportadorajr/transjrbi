module WorkScheduleDaysHelper
  def work_schedule_day_form_title(day_form)
    return t('work_schedule_days.form.title') if day_form.employee.nil?

    t('work_schedule_days.form.employee_title', name: day_form.employee.name)
  end

  def work_schedule_day_city_options(day_form)
    day_form.available_cities.map { |city| [work_schedule_day_city_label(city), city.id] }
  end

  def work_schedule_day_detail_label(work_schedule_day)
    WorkScheduleDay.human_attribute_name(work_schedule_day.leave? ? :leave_reason_type : :city)
  end

  def work_schedule_day_detail(work_schedule_day)
    return work_schedule_day.leave_reason_type_name if work_schedule_day.leave?
    return t('tax.blank') if work_schedule_day.city.nil?

    work_schedule_day_city_label(work_schedule_day.city)
  end

  def work_schedule_day_destroy_button(work_schedule_day)
    return unless can?(:destroy, :work_schedules)

    link_to work_schedule_day_path(work_schedule_day), class: 'btn btn-outline-danger btn-round px-4',
                                                       data: { turbo_method: :delete,
                                                               turbo_confirm: t('work_schedule_days.entry.confirm_destroy') } do
      safe_join([icon(:'x-circle', class: 'me-2'), t('work_schedule_days.entry.destroy')])
    end
  end

  private

  def work_schedule_day_city_label(city)
    t("work_schedule_days.city.#{city.base? ? :base : :not_base}", city: tax_city(city.name, city.state))
  end
end
