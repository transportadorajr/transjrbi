module EmptyLegsHelper
  def empty_leg_manifest_link(manifest, code)
    return code.to_s unless manifest
    return manifest.number unless manifest.active? && can?(:read, :manifests)

    link_to manifest.number, manifest_path(manifest), class: 'fw-semibold text-decoration-none'
  end

  def empty_leg_location(location)
    return t('tax.blank') unless location

    [location.street, tax_city(location.city, location.state)].compact_blank.join(' - ')
  end

  def empty_leg_total(total)
    t('empty_legs.distance', distance: number_with_precision(total, precision: 2))
  end

  def empty_leg_average(average_km)
    return t('tax.blank') unless average_km

    empty_leg_total(average_km)
  end

  def empty_leg_loading_macro_region(empty_leg)
    empty_leg[:loading_macro_region_name] || t('empty_legs.index.no_macro_region')
  end

  def empty_leg_macro_region_options(macro_regions)
    options = macro_regions.map { |macro_region| [macro_region_label(macro_region), macro_region.id] }

    options_for_select(options + [[t('empty_legs.index.no_macro_region'), MacroRegion::OTHERS]], params[:macro_region_id])
  end

  def empty_leg_customer_group_options(customer_groups)
    options_for_select(customer_groups.map { |customer_group| [customer_group.name, customer_group.id] }, params[:customer_group_id])
  end

  def empty_leg_distance(empty_leg)
    return empty_leg.status_type_name unless empty_leg.calculated?

    t('empty_legs.distance', distance: number_with_precision(empty_leg.distance_km, precision: 2))
  end
end
