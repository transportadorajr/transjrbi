module RevenueProjectionDayNotesHelper
  def revenue_projection_day_note_title(day_note_form)
    t('revenue_projection_day_notes.modal.title', date: l(day_note_form.date, format: :with_weekday))
  end
end
