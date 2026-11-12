require 'rails_helper'

RSpec.describe TonnageRates::ReplicateMonthJob do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  around { |example| travel_to(Time.zone.local(2026, 11, 1, 0, 5)) { example.run } }

  before { create(:tonnage_rate, tenant:, customer_group: create(:customer_group, tenant:), valid_month: Date.new(2026, 10, 1)) }

  it 'copies the rates of every tenant and recalculates the freight expenses only where it copied' do
    expect { described_class.perform_now }
      .to change(TonnageRate, :count).by(1)
      .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id).exactly(:once)

    expect(tenant.tonnage_rates.find_by!(valid_month: Date.new(2026, 11, 1))).to be_pending_review
    expect(other_tenant.tonnage_rates).to be_empty
  end

  it 'is scheduled on the first day of every month right after midnight' do
    expect(GoodJob.configuration.cron.fetch(:tonnage_rates_monthly_copy).slice(:cron, :class))
      .to eq(cron: '5 0 1 * * America/Sao_Paulo', class: 'TonnageRates::ReplicateMonthJob')
  end
end
