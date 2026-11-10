module ChartsHelper
  BRAND_BLUE = '#2563eb'.freeze
  DANGER_RED = '#dc3545'.freeze
  CHART_GRID_COLOR = '#eef0f4'.freeze
  CHART_TEXT_COLOR = '#52514e'.freeze
  CHART_HEIGHT = '320px'.freeze
  RANKING_BAR_HEIGHT = 44
  RANKING_MIN_HEIGHT = 320
  RANKING_BAR_LABELS = { display: true, anchor: 'end', clamp: true, padding: { top: 0, right: 4, bottom: 0, left: 4 },
                         font: { size: 11, weight: 600 } }.freeze
  EVOLUTIONS = %w[monthly weekly].freeze
  DEFAULT_EVOLUTION = 'monthly'.freeze

  def chart_evolutions
    EVOLUTIONS
  end

  def chart_evolution_reveal_data
    { controller: 'reveal', reveal_key_value: DEFAULT_EVOLUTION, reveal_active_class: 'btn-primary',
      reveal_inactive_class: 'btn-outline-secondary', reveal_hidden_class: 'd-none' }
  end

  def chart_evolution_button(evolution)
    default = evolution == DEFAULT_EVOLUTION

    button_tag t(evolution, scope: 'shared.evolutions'), type: :button, class: ['btn btn-sm', default ? 'btn-primary' : 'btn-outline-secondary'],
                                                         aria: { pressed: default },
                                                         data: { reveal_target: 'button', reveal_key_param: evolution, action: 'reveal#show' }
  end

  def chart_evolution_item(evolution, &)
    tag.div(class: ['h-100', ('d-none' unless evolution == DEFAULT_EVOLUTION)], data: { reveal_target: 'item', reveal_key: evolution }, &)
  end

  def chart_money_options
    { prefix: "#{t('number.currency.format.unit')} ", thousands: t('number.currency.format.delimiter'),
      decimal: t('number.currency.format.separator'), round: 2, zeros: true }
  end

  def chart_bar_library(category_axis)
    value_axis = category_axis == :x ? :y : :x

    {
      scales: {
        category_axis => { grid: { display: false }, ticks: { color: CHART_TEXT_COLOR, autoSkip: false } },
        value_axis => { border: { display: false }, grid: { color: CHART_GRID_COLOR },
                        ticks: { color: CHART_TEXT_COLOR, maxRotation: 0, autoSkipPadding: 16 } },
      },
      plugins: { legend: { labels: { color: CHART_TEXT_COLOR, usePointStyle: true, pointStyle: 'circle', boxWidth: 8, padding: 16 } } },
    }
  end
end
