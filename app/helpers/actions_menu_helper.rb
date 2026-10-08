module ActionsMenuHelper
  def responsive_actions_menu(menus)
    responsive_actions(menus.map { |menu| menu.to_h.deep_symbolize_keys.merge(url: menu.url) })
  end

  def responsive_actions(actions)
    inline = inline_actions(actions)

    return inline if actions.size < 2

    capture do
      concat(content_tag(:div, inline, class: 'd-none d-lg-block inline-actions'))
      concat(' ')
      concat(actions_dropdown(actions))
    end
  end

  def inline_actions(actions)
    capture do
      actions.each do |action|
        concat(inline_action(action))
        concat(' ')
      end
    end
  end

  def actions_dropdown(actions)
    content_tag(:div, class: 'dropdown d-lg-none dropdown-actions') do
      concat(actions_dropdown_toggle)

      ul = content_tag(:ul, class: 'dropdown-menu dropdown-menu-end') do
        actions.each do |action|
          concat(content_tag(:li, dropdown_action(action)))
          concat("\n")
        end

        nil
      end

      concat ul
    end
  end

  private

  def actions_dropdown_toggle
    content_tag(:button,
                safe_join([icon(:'three-dots-vertical'), content_tag(:span, t('layouts.main.options'), class: 'visually-hidden')]),
                class: 'btn btn-outline-dark btn-sm btn-icon',
                type: :button,
                data: { bs_toggle: 'dropdown', bs_popper_config: { strategy: 'fixed' } },
                aria: { expanded: false })
  end

  def inline_action(action)
    link_to_action(action[:name], action[:record], action[:url], icon: action[:icon], **action_options(action, except: %i[name record url icon]))
  end

  def dropdown_action(action)
    klasses = "dropdown-item d-flex #{action[:class]} text-#{action_menu_color(action)}".squish
    content = safe_join([icon(action[:icon]), content_tag(:span, action_label(action), class: 'ms-2')])

    link_to(action[:url], class: klasses, **action_options(action, except: %i[name record url icon class color label])) { content }
  end

  def action_label(action)
    return action[:label] if action[:label].present?

    label = action_i18n(:tooltips, action[:name], action[:record]) if action[:record]

    label.presence || action[:name].to_s.humanize
  end

  def action_menu_color(action)
    action[:color] || action_color(action[:name])
  end

  def action_options(action, except:)
    action.except(*except).to_h.deep_symbolize_keys
  end
end
