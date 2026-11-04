module RouteDistancesHelper
  def route_distances_menu(route_distance)
    menus = []

    menus << route_distance_edit_menu(route_distance) if can?(:update, :route_distances)
    menus << route_distance_destroy_menu(route_distance) if can?(:destroy, :route_distances)

    menus
  end

  def route_distance_create_button
    create_button(t('route_distances.index.new_route_distance')) if can?(:create, :route_distances)
  end

  def route_distance_import_button
    return unless can?(:create, :route_distances)

    link_to '#routeDistanceImportModal', class: 'btn btn-outline-secondary btn-round', data: { bs_toggle: :modal } do
      concat icon(:'file-earmark-spreadsheet', class: 'me-2')
      concat t('route_distances.index.import')
    end
  end

  def route_distance_sort_columns
    [
      [RouteDistance.human_attribute_name(:customer), :customer_name],
      [RouteDistance.human_attribute_name(:origin_city), :origin_city],
      [RouteDistance.human_attribute_name(:destination_city), :destination_city],
      [RouteDistance.human_attribute_name(:distance_km), :distance_km, :desc],
    ]
  end

  def route_distance_customer_options(customers)
    customers.map do |customer|
      [[customer.name, customer.document].compact_blank.join(' - ').presence || customer.code.to_s, customer.code.to_s]
    end
  end

  def route_distance_customer(route_distance)
    route_distance.customer&.name.presence || route_distance.customer_code.to_s
  end

  def route_distance_route(route_distance)
    t('transport_documents.route', origin: tax_city(route_distance.origin_city, route_distance.origin_state),
                                   destination: tax_city(route_distance.destination_city, route_distance.destination_state))
  end

  def route_distance_km(distance_km)
    t('route_distances.km', distance: number_with_precision(distance_km, precision: 2))
  end

  def route_distance_form_url(route_distance_form)
    return route_distances_path unless route_distance_form.persisted?

    route_distance_path(route_distance_form.route_distance)
  end

  def route_distance_submit_label(route_distance_form)
    t("helpers.submit.route_distance.#{route_distance_form.persisted? ? 'update' : 'create'}")
  end

  private

  def route_distance_edit_menu(route_distance)
    Menu.new(name: :edit, record: route_distance, url: edit_route_distance_path(route_distance), icon: :pencil)
  end

  def route_distance_destroy_menu(route_distance)
    Menu.new(
      name: :destroy,
      record: route_distance,
      url: route_distance_path(route_distance),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('route_distances.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
