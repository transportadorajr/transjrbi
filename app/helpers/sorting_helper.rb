module SortingHelper
  ARIA_SORT = { 'asc' => 'ascending', 'desc' => 'descending' }.freeze
  DIRECTION_ICONS = { 'asc' => :'arrow-up', 'desc' => :'arrow-down' }.freeze

  def sortable_header(label, column, first_direction: :asc, anchor: nil, **)
    content_tag :th, aria: { sort: ARIA_SORT[current_sort_direction(column)] }, ** do
      link_to sort_path(column, first_direction, anchor), class: ['sort-link', ('sort-link-active' if current_sort_direction(column))] do
        safe_join([label, icon(sort_icon(column), class: 'sort-link-icon')])
      end
    end
  end

  def sort_menu(columns)
    return if columns.empty?

    content_tag :div, class: 'dropdown d-md-none' do
      safe_join([sort_menu_toggle, sort_menu_items(columns)])
    end
  end

  def sort_fields
    safe_join(%i[sort direction].filter_map { |name| hidden_field_tag(name, params[name], id: nil) if params[name].is_a?(String) })
  end

  private

  def sort_menu_toggle
    link_to t('shared.sort_by'), '#', class: 'btn btn-sm btn-outline-secondary btn-round dropdown-toggle', role: :button,
                                      data: { bs_toggle: :dropdown }, aria: { expanded: false }
  end

  def sort_menu_items(columns)
    content_tag :ul, class: 'dropdown-menu dropdown-menu-end' do
      safe_join(columns.map { |label, column, first_direction| content_tag(:li, sort_menu_item(label, column, first_direction)) })
    end
  end

  def sort_menu_item(label, column, first_direction)
    link_to sort_path(column, first_direction || :asc, nil), class: 'dropdown-item d-flex justify-content-between align-items-center gap-3' do
      safe_join([label, icon(sort_icon(column), class: 'sort-link-icon')])
    end
  end

  def sort_path(column, first_direction, anchor)
    query = request.query_parameters.except('page').merge(sort: column, direction: next_sort_direction(column, first_direction))

    "#{request.path}?#{query.to_query}#{"##{anchor}" if anchor}"
  end

  def next_sort_direction(column, first_direction)
    case current_sort_direction(column)
    when 'asc' then 'desc'
    when 'desc' then 'asc'
    else first_direction.to_s
    end
  end

  def current_sort_direction(column)
    return unless params[:sort].to_s == column.to_s

    params[:direction].to_s == 'desc' ? 'desc' : 'asc'
  end

  def sort_icon(column)
    DIRECTION_ICONS.fetch(current_sort_direction(column), :'arrow-down-up')
  end
end
