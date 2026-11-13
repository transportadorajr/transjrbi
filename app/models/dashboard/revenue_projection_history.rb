module Dashboard
  class RevenueProjectionHistory
    HIT_TOLERANCE = 0.05
    LABEL_FORMAT = :chart_week
    SNAPSHOT_PERIOD_TYPES = %w[month week].freeze

    DayRow = Data.define(:date, :day_type, :forecast_cents, :billed_cents, :documents_count, :projected_cents, :note) do
      extend ActiveModel::Naming

      def confirmation_name
        I18n.l(date)
      end

      def difference_cents
        billed_cents - forecast_cents if forecast_cents
      end

      def difference_ratio
        difference_cents.to_f / forecast_cents if forecast_cents&.positive?
      end
    end

    WeekRow = Data.define(:period, :opening_cents, :forecast_cents, :billed_cents, :closed) do
      def difference_cents
        billed_cents - opening_cents if closed && opening_cents
      end

      def difference_ratio
        difference_cents.to_f / opening_cents if difference_cents && opening_cents.positive?
      end
    end

    attr_reader :period_type, :period

    def initialize(tenant, period_type, period, today: Date.current, memory: ::RevenueProjection::StoredMemory.new(tenant))
      @tenant = tenant
      @period_type = period_type.to_s
      @period = period
      @today = today
      @memory = memory
    end

    def start
      period.first
    end

    def starts
      @starts ||= tenant.revenue_projection_snapshots.where(period_type:).distinct.order(period_start: :desc).pluck(:period_start)
    end

    def any?
      return snapshots.any? if snapshot_period?

      totals.any? || forecasts.any?
    end

    def month?
      period_type == 'month'
    end

    def week?
      period_type == 'week'
    end

    def snapshot_period?
      SNAPSHOT_PERIOD_TYPES.include?(period_type)
    end

    def closed?
      today > period.last
    end

    def last_closed_date
      [period.last, today.yesterday].min
    end

    def snapshots
      return [] unless snapshot_period?

      @snapshots ||= memory.snapshots_of(period_type, start)
    end

    def opening
      snapshots.first
    end

    def latest
      snapshots.last
    end

    def billed_cents
      closed_days.sum { totals[it]&.billed_cents.to_i }
    end

    def forecast_cents
      forecasts.values_at(*closed_days).compact.sum(&:forecast_cents)
    end

    def difference_cents
      return billed_cents - forecast_cents unless snapshot_period?

      (closed? ? billed_cents : latest.projected_cents) - opening.projected_cents
    end

    def difference_ratio
      base = snapshot_period? ? opening.projected_cents : forecast_cents
      difference_cents.to_f / base if base.positive?
    end

    def hit_since
      return unless closed? && billed_cents.positive?

      hits = snapshots.reverse.take_while { ((it.projected_cents - billed_cents).abs / billed_cents.to_f) <= HIT_TOLERANCE }
      hits.last&.taken_on
    end

    def reconstructed_period
      return if memory.recalculated?

      reconstructed = snapshots.select(&:reconstructed)
      reconstructed.first.taken_on..reconstructed.last.taken_on if reconstructed.any?
    end

    def day_rows
      closed_days.map do |date|
        total = totals[date]
        forecast = forecasts[date]

        DayRow.new(date:, day_type: (total || forecast)&.day_type || 'regular', forecast_cents: forecast&.forecast_cents,
                   billed_cents: total&.billed_cents.to_i, documents_count: total&.documents_count.to_i,
                   projected_cents: snapshots_by_date[date]&.projected_cents, note: notes[date])
      end
    end

    def week_rows
      return [] if week?

      period.chunk_while { |_, date| !date.sunday? }.select { it.first <= today }.map do |dates|
        range = dates.first..dates.last
        billed_dates = dates.select { it <= last_closed_date }

        WeekRow.new(period: range, opening_cents: week_opening_cents(range), forecast_cents: forecasts.values_at(*billed_dates).compact.sum(&:forecast_cents),
                    billed_cents: billed_dates.sum { totals[it]&.billed_cents.to_i }, closed: range.last <= last_closed_date)
      end
    end

    def chart_data
      return range_chart_data unless snapshot_period?

      series = [
        { name: I18n.t(period_type, scope: 'dashboards.revenue_projection_history.projected'), data: chart_points(&:projected_cents) },
        { name: I18n.t('dashboards.revenue_projection_history.low'), data: chart_points(&:low_cents) },
        { name: I18n.t('dashboards.revenue_projection_history.high'), data: chart_points(&:high_cents) },
        { name: I18n.t('dashboards.revenue_projection_history.realized'), data: billed_points },
      ]
      series << { name: I18n.t(period_type, scope: 'dashboards.revenue_projection_history.billed'), data: chart_points { billed_cents } } if closed?
      series
    end

    private

    attr_reader :tenant, :today, :memory

    def closed_days
      period.first..last_closed_date
    end

    def snapshots_by_date
      @snapshots_by_date ||= (snapshot_period? ? snapshots : memory.snapshots_taken('month', period)).index_by(&:taken_on)
    end

    def week_snapshots
      @week_snapshots ||= memory.week_snapshots_within(period).group_by(&:period_start)
    end

    def week_opening_cents(range)
      snapshot = week_snapshots[range.first.beginning_of_week(RevenueProjections::CalculateCommand::WEEK_START)]&.first
      return unless snapshot

      snapshot.days.select { range.cover?(Date.iso8601(it['date'])) }.sum { it['realized_cents'] + it['expected_cents'] }
    end

    def totals
      @totals ||= memory.totals(period)
    end

    def notes
      @notes ||= tenant.revenue_projection_day_notes.where(date: period).preload(:user).index_by(&:date)
    end

    def forecasts
      @forecasts ||= memory.forecasts(period)
    end

    def chart_points(&)
      snapshots.to_h { [I18n.l(it.taken_on, format: LABEL_FORMAT), Money.from_cents(yield(it)).to_f] }
    end

    def billed_points
      accumulated = accumulated_billed
      snapshots.select { accumulated.key?(it.taken_on) }.to_h { [I18n.l(it.taken_on, format: LABEL_FORMAT), Money.from_cents(accumulated[it.taken_on]).to_f] }
    end

    def accumulated_billed
      sum = 0
      closed_days.index_with { |date| sum += totals[date]&.billed_cents.to_i }
    end

    def range_chart_data
      [
        { name: I18n.t('dashboards.revenue_projection_history.forecast_accumulated'), data: accumulated_points { forecasts[it]&.forecast_cents.to_i } },
        { name: I18n.t('dashboards.revenue_projection_history.realized'), data: accumulated_points { totals[it]&.billed_cents.to_i } },
      ]
    end

    def accumulated_points
      sum = 0
      closed_days.to_h do |date|
        sum += yield(date)
        [I18n.l(date, format: LABEL_FORMAT), Money.from_cents(sum).to_f]
      end
    end
  end
end
