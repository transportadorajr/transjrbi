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

  describe '#goal_week_value' do
    it 'shows a dash outside the current week' do
      expect(helper.goal_week_value(row(goal_cents: nil), 'R$ 1,00')).to eq('-')
      expect(helper.goal_week_value(row_class.new(key: 'x', label: 'x', goal_cents: nil, realized_cents: 0, projected_cents: 0, week_realized_cents: 0),
                                    'R$ 1,00')).to eq('R$ 1,00')
    end
  end

  describe '#goal_row_menu' do
    let(:tenant) { create(:tenant) }
    let(:cut_row) { row_class.new(key: 'AJR4391', label: 'AJR4391', goal_cents: nil, realized_cents: 0, projected_cents: 0, cut: { plate: 'AJR4391' }) }

    before do
      Current.tenant = tenant
      allow(helper).to receive(:can?).with(:read, :revenue_projection).and_return(true)
    end

    it 'links to the projection history of the row with access to the projection' do
      menu = helper.goal_row_menu(cut_row, Date.new(2026, 11, 1)).sole

      expect(menu.url).to eq('/revenue_projection_history?end_date=2026-11-30&plate=AJR4391&start_date=2026-11-01')
    end

    it 'has no link when the row has no cut' do
      expect(helper.goal_row_menu(row(goal_cents: nil), Date.new(2026, 11, 1))).to be_empty
    end

    it 'has no link without access to the projection' do
      allow(helper).to receive(:can?).with(:read, :revenue_projection).and_return(false)

      expect(helper.goal_row_menu(cut_row, Date.new(2026, 11, 1))).to be_empty
    end
  end
end
