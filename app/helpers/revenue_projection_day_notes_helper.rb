module RevenueProjectionDayNotesHelper
  def revenue_projection_day_note_title(day_note_form)
    t('revenue_projection_day_notes.modal.title', date: l(day_note_form.date, format: :with_weekday))
  end

  def revenue_projection_day_note_history_params
    params.permit(:start_date, :end_date).to_h.symbolize_keys
  end
end
