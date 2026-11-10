module ListingFiltersHelper
  def listing_period_presets
    FreightBillingFilterForm::PERIOD_PRESETS
  end

  def listing_period_preset_label(preset)
    t(preset, scope: 'listing_filters.period_presets')
  end

  def listing_period_preset_path(preset)
    period = FreightBillingFilterForm.preset_period(preset)

    listing_url(start_date: period.first.iso8601, end_date: period.last.iso8601)
  end

  def listing_period_preset_link_class(preset)
    period = FreightBillingFilterForm.preset_period(preset)
    active = params[:start_date] == period.first.iso8601 && params[:end_date] == period.last.iso8601

    listing_chip_class(active)
  end

  def listing_dimensions
    Dashboard::ListingGroups::DIMENSIONS
  end

  def listing_dimension_label(dimension)
    t(dimension, scope: 'listing_filters.dimensions')
  end

  def listing_dimension_path(dimension, groups)
    listing_url(dimension: dimension == groups.dimension ? nil : dimension)
  end

  def listing_dimension_link_class(dimension, groups)
    listing_chip_class(dimension == groups.dimension)
  end

  def listing_dimension_field
    hidden_field_tag(:dimension, params[:dimension], id: nil) if params[:dimension].is_a?(String)
  end

  def listing_groups_card(groups, count_label:)
    return unless groups.grouped?

    render 'shared/listing_groups', groups:, count_label:
  end

  def listing_groups_title(groups)
    t('listing_filters.groups.title', dimension: listing_dimension_label(groups.dimension).downcase)
  end

  def listing_group_label(row, groups)
    return row.label unless row.filterable?

    link_to row.label, listing_url(groups.filter_param => row.key), class: 'fw-semibold text-decoration-none text-break'
  end

  def listing_groups_net_header(groups)
    return if groups.total.net.nil?

    content_tag(:th, t('listing_filters.groups.net'), class: 'd-none d-md-table-cell text-end')
  end

  def listing_groups_net_cell(row)
    return if row.net.nil?

    content_tag(:td, tax_money(row.net), class: 'd-none d-md-table-cell text-end text-nowrap')
  end

  def listing_groups_duration_headers(groups)
    return unless groups.durations?

    headers = [content_tag(:th, t('listing_filters.groups.average_duration'), class: 'd-none d-md-table-cell text-end')]
    headers << content_tag(:th, t('listing_filters.groups.net_per_hour'), class: 'd-none d-lg-table-cell text-end') unless groups.total.net.nil?

    safe_join(headers)
  end

  def listing_groups_duration_cells(row, groups)
    return unless groups.durations?

    cells = [content_tag(:td, trip_duration(row.durations.average), class: 'd-none d-md-table-cell text-end text-nowrap')]
    cells << content_tag(:td, tax_money(row.durations.net_per_hour), class: 'd-none d-lg-table-cell text-end text-nowrap') unless row.net.nil?

    safe_join(cells)
  end

  private

  def listing_url(changes)
    url_for(request.query_parameters.except('page').merge(changes.stringify_keys).compact_blank.merge(only_path: true))
  end

  def listing_chip_class(active)
    "btn btn-sm #{active ? 'btn-primary' : 'btn-outline-secondary'}"
  end
end
