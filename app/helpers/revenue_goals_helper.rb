module RevenueGoalsHelper
  def revenue_goals_edit_button(month)
    return unless can?(:update, :revenue_goals)

    link_to edit_revenue_goals_path(month: goal_month_param(month)), class: 'btn btn-primary btn-primary-action btn-round' do
      safe_join([icon(:pencil, class: 'me-2'), t('revenue_goals.show.edit')])
    end
  end

  def revenue_goals_replicate_button(month)
    return unless can?(:update, :revenue_goals)

    button_to replicate_revenue_goals_path(month: goal_month_param(month)), class: 'btn btn-outline-secondary btn-round',
                                                                            form: { data: { turbo_confirm: t('revenue_goals.show.confirm_replicate',
                                                                                                             month: goal_month_name(month.prev_month)) } } do
      safe_join([icon(:files, class: 'me-2'), t('revenue_goals.show.replicate')])
    end
  end

  def revenue_goals_panel_button(month)
    return unless can?(:read, :goals)

    link_to goals_path(month: goal_month_param(month)), class: 'btn btn-outline-secondary btn-round' do
      safe_join([icon(:speedometer2, class: 'me-2'), t('revenue_goals.show.panel')])
    end
  end

  def revenue_goals_vehicles(form)
    return render('shared/no_content') if form.vehicles.empty?

    render 'revenue_goals/table', vehicles: form.vehicles
  end
end
