module SortingHelper
  ARIA_SORT = { 'asc' => 'ascending', 'desc' => 'descending' }.freeze
  DIRECTION_ICONS = { 'asc' => :'arrow-up', 'desc' => :'arrow-down' }.freeze

  def sortable_header(label, column, first_direction: :asc, anchor: nil, scope: nil, frame: nil, **)
    direction = current_sort_direction(column, scope)

    content_tag :th, aria: { sort: ARIA_SORT[direction] }, ** do
      link_to sort_path(column, first_direction, anchor, scope), class: ['sort-link', ('sort-link-active' if direction)],
                                                                 data: { turbo_frame: frame }.compact do
        safe_join([label, icon(sort_icon(column, scope), class: 'sort-link-icon')])
      end
    end
  end

  def sort_menu(columns, scope: nil, frame: nil)
    return if columns.empty?

    content_tag :div, class: 'dropdown d-md-none' do
      safe_join([sort_menu_toggle, sort_menu_items(columns, scope, frame)])
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

  def sort_menu_items(columns, scope, frame)
    content_tag :ul, class: 'dropdown-menu dropdown-menu-end' do
      safe_join(columns.map { |label, column, first_direction| content_tag(:li, sort_menu_item(label, column, first_direction, scope, frame)) })
    end
  end

  def sort_menu_item(label, column, first_direction, scope, frame)
    link_to sort_path(column, first_direction || :asc, nil, scope), class: 'dropdown-item d-flex justify-content-between align-items-center gap-3',
                                                                    data: { turbo_frame: frame }.compact do
      safe_join([label, icon(sort_icon(column, scope), class: 'sort-link-icon')])
    end
  end

  def sort_path(column, first_direction, anchor, scope = nil)
    sort_key, direction_key = sort_param_keys(scope)
    query = request.query_parameters.except('page').merge(sort_key => column.to_s, direction_key => next_sort_direction(column, first_direction, scope))

    "#{request.path}?#{query.to_query}#{"##{anchor}" if anchor}"
  end

  def next_sort_direction(column, first_direction, scope)
    case current_sort_direction(column, scope)
    when 'asc' then 'desc'
    when 'desc' then 'asc'
    else first_direction.to_s
    end
  end

  def current_sort_direction(column, scope = nil)
    sort_key, direction_key = sort_param_keys(scope)
    return unless params[sort_key].to_s == column.to_s

    params[direction_key].to_s == 'desc' ? 'desc' : 'asc'
  end

  def sort_icon(column, scope = nil)
    DIRECTION_ICONS.fetch(current_sort_direction(column, scope), :'arrow-down-up')
  end

  def sort_param_keys(scope)
    scope ? %W[#{scope}_sort #{scope}_direction] : %w[sort direction]
  end
end
