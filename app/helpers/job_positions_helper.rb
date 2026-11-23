module JobPositionsHelper
  def job_positions_menu(job_position)
    menus = []

    menus << job_position_edit_menu(job_position) if can?(:update, :job_positions)
    menus << activation_menu(job_position, active: job_position.activated?) if can?(:update, :job_positions)

    menus
  end

  def job_position_status_badge(job_position)
    if job_position.activated?
      status_badge(t('job_positions.status.active'), kind: :success)
    else
      status_badge(t('job_positions.status.inactive'), kind: :danger)
    end
  end

  def job_position_employees_count(job_position, employee_counts)
    employee_counts.fetch(job_position.id, 0)
  end

  def job_position_status_options
    options_for_select(JobPosition.statuses, params[:status])
  end

  def job_position_form_url(job_position_form)
    job_position_form.persisted? ? job_position_path(job_position_form.job_position) : job_positions_path
  end

  def job_position_form_submit_label(job_position_form)
    t("helpers.submit.job_position.#{job_position_form.persisted? ? :update : :create}")
  end

  def job_position_create_button
    create_button(t('job_positions.index.new_job_position')) if can?(:create, :job_positions)
  end

  private

  def job_position_edit_menu(job_position)
    Menu.new(name: :edit, record: job_position, url: edit_job_position_path(job_position), icon: :pencil)
  end
end
