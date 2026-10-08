module ApplicationHelper
  COUNTER_ICONS = { dark: 'grid', success: 'check-circle', danger: 'x-circle', warning: 'exclamation-circle', primary: 'bar-chart' }.freeze

  def icon(name, options = {})
    tag.i(**options, class: ['bi', "bi-#{name}", options[:class]], aria: { hidden: true })
  end

  def page_header_tag(title, subtitle: nil, back_path: nil, back_title: nil, wrapper_class: nil, &actions)
    content_tag :div, class: ['page-header', wrapper_class].compact.join(' ') do
      concat(page_header_title_tag(title, subtitle:, back_path:, back_title:))
      concat(content_tag(:div, capture(&actions), class: 'page-actions')) if block_given?
    end
  end

  def create_button(title, path = new_record_path, **)
    link_to path, class: 'btn btn-primary btn-primary-action btn-round', ** do
      concat icon(:'plus-circle', class: 'me-2')
      concat title
    end
  end

  def link_to_filters(modal_id, **options)
    link_to icon(:funnel), modal_id,
            data: { bs_toggle: :modal },
            class: options.fetch(:class, 'btn btn-sm btn-primary btn-round ms-1'),
            aria: { label: t('shared.filters') }
  end

  def link_to_action(action, entity, path, icon:, data: {}, color: nil, **options)
    title = action_i18n(:tooltips, action, entity)
    confirm = action_i18n(:confirms, action, entity)

    data = { **data }
    data[:turbo_confirm] ||= confirm if confirm.present?

    color ||= action_color(action)

    klass = options.delete(:class)
    klass = [klass, 'btn', "btn-outline-#{color}", 'btn-sm', 'btn-icon'].compact.join(' ')

    link_to icon(icon), path, class: klass, title:, aria: { label: title }, **options, data:
  end

  def action_color(action)
    return :danger if action == :destroy

    :dark
  end

  def action_i18n(scope, action, model)
    key = [:helpers, scope, model.class.model_name.i18n_key, action].join('.')

    t(key, model: model.confirmation_name) if I18n.exists?(key)
  end

  def counter_card(kind, label, value, col_class: 'col-12 col-md-4')
    content_tag :div, class: "counter-card #{col_class}" do
      content_tag :div, class: 'card h-100' do
        content_tag :div, class: 'counter-card-body' do
          concat content_tag(:div, class: "counter-icon-wrap icon-#{kind}") {
            content_tag(:i, nil, class: "bi bi-#{COUNTER_ICONS.fetch(kind.to_sym, 'circle')}")
          }
          concat content_tag(:div, class: 'counter-card-info') {
            concat content_tag(:p, label, class: 'counter-label')
            concat content_tag(:strong, value, class: "counter-value value-#{kind} d-block")
          }
        end
      end
    end
  end

  def status_badge(status, kind: :success)
    content_tag :span, status, class: "badge bg-#{kind}-subtle text-#{kind} px-3 py-2 rounded-pill"
  end

  private

  def new_record_path
    send("new_#{controller_name.singularize}_path")
  end

  def page_header_title_tag(title, subtitle:, back_path:, back_title:)
    return page_header_title_with_back_tag(title, back_path, back_title) if back_path

    content_tag :div, class: 'page-header-title' do
      concat content_tag(:h1, title, class: 'page-title')
      concat content_tag(:p, subtitle, class: 'page-subtitle') if subtitle.present?
    end
  end

  def page_header_title_with_back_tag(title, back_path, back_title)
    content_tag :div, class: 'd-flex align-items-center gap-3 page-header-title' do
      concat link_to(icon(:'arrow-left'), back_path, class: 'btn-back', title: back_title, aria: { label: back_title })
      concat content_tag(:h1, title, class: 'page-title')
    end
  end
end
