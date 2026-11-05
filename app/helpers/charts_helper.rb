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
