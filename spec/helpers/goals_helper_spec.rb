require 'rails_helper'

RSpec.describe GoalsHelper do
  let(:row_class) { Dashboard::Goals::Row }

  def row(goal_cents:, realized_cents: 500, projected_cents: 1_000)
    row_class.new(key: 'AJR4391', label: 'AJR4391', goal_cents:, realized_cents:, projected_cents:)
  end

  describe '#goal_status_badge' do
    it 'translates the status of the projection against the goal' do
      expect(helper.goal_status_badge(row(goal_cents: 1_000))).to include('No ritmo', 'bg-success-subtle')
      expect(helper.goal_status_badge(row(goal_cents: 1_100))).to include('Atenção', 'bg-warning-subtle')
      expect(helper.goal_status_badge(row(goal_cents: 2_000))).to include('Abaixo da meta', 'bg-danger-subtle')
      expect(helper.goal_status_badge(row(goal_cents: nil))).to include('Sem meta', 'bg-secondary-subtle')
    end
  end

  describe '#goal_money and #goal_ratio' do
    it 'shows a missing goal as no goal' do
      expect(helper.goal_money(nil)).to eq('Sem meta')
      expect(helper.goal_money(1_234_550)).to eq('R$ 12.345,50')
      expect(helper.goal_ratio(nil)).to eq('Sem meta')
      expect(helper.goal_ratio(BigDecimal('0.9'))).to eq('90,0%')
    end
  end

  describe '#goal_progress' do
    it 'caps the bar at the goal' do
      expect(helper.goal_progress(row(goal_cents: 400))).to include('value="400"', 'max="400"', 'goal-progress-success')
      expect(helper.goal_progress(row(goal_cents: nil))).to be_nil
    end
  end

  describe '#goal_pace_note' do
    it 'explains how the projection was made' do
      pace = RevenueGoal::Pace.new(Date.new(2026, 11, 1), reference_date: Date.new(2026, 11, 10), holidays: {})
      dashboard = instance_double(Dashboard::Goals, pace:)

      expect(helper.goal_pace_note(dashboard)).to eq('Projeção pelo ritmo atual, com 8 de 25 dias úteis do mês já decorridos.')
    end
  end
end
