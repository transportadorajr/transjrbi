module DistanceAdjustmentsHelper
  def distance_adjustments_menu(distance_adjustment)
    menus = []

    menus << distance_adjustment_edit_menu(distance_adjustment) if can?(:update, :distance_adjustments)
    menus << distance_adjustment_destroy_menu(distance_adjustment) if can?(:destroy, :distance_adjustments)

    menus
  end

  def distance_adjustment_create_button
    create_button(t('distance_adjustments.index.new_distance_adjustment')) if can?(:create, :distance_adjustments)
  end

  def distance_adjustment_import_button
    return unless can?(:create, :distance_adjustments)

    link_to '#distanceAdjustmentImportModal', class: 'btn btn-outline-secondary btn-round', data: { bs_toggle: :modal } do
      concat icon(:'file-earmark-spreadsheet', class: 'me-2')
      concat t('distance_adjustments.index.import')
    end
  end

  def distance_adjustment_sort_columns
    [
      [DistanceAdjustment.human_attribute_name(:transport_document_number), :transport_document_number],
      [DistanceAdjustment.human_attribute_name(:distance_km), :distance_km, :desc],
      [DistanceAdjustment.human_attribute_name(:applied_at), :applied_at, :desc],
    ]
  end

  def distance_adjustment_form_url(distance_adjustment_form)
    return distance_adjustments_path unless distance_adjustment_form.persisted?

    distance_adjustment_path(distance_adjustment_form.distance_adjustment)
  end

  def distance_adjustment_submit_label(distance_adjustment_form)
    t("helpers.submit.distance_adjustment.#{distance_adjustment_form.persisted? ? 'update' : 'create'}")
  end

  def distance_adjustment_status_badge(distance_adjustment)
    return status_badge(t('distance_adjustments.index.applied'), kind: :success) if distance_adjustment.applied?

    status_badge(t('distance_adjustments.index.pending'), kind: :warning)
  end

  def distance_adjustment_km(distance_km)
    t('distance_adjustments.km', distance: number_with_precision(distance_km, precision: 2))
  end

  private

  def distance_adjustment_edit_menu(distance_adjustment)
    Menu.new(name: :edit, record: distance_adjustment, url: edit_distance_adjustment_path(distance_adjustment), icon: :pencil)
  end

  def distance_adjustment_destroy_menu(distance_adjustment)
    Menu.new(
      name: :destroy,
      record: distance_adjustment,
      url: distance_adjustment_path(distance_adjustment),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('distance_adjustments.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
