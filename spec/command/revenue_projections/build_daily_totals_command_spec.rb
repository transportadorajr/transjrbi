require 'rails_helper'

RSpec.describe RevenueProjections::BuildDailyTotalsCommand do
  let(:tenant) { create(:tenant) }

  before do
    create(:holiday, tenant:, date: Date.new(2026, 11, 2), name: 'Finados')
    create(:atua_transport_document, tenant:, plate: 'AAA1A11', issued_at: Time.zone.local(2026, 11, 2, 9, 30), freight_cents: 40_000)
    create(:atua_transport_document, tenant:, plate: 'AAA1A11', issued_at: Time.zone.local(2026, 11, 2, 14), freight_cents: 10_000)
    create(:atua_transport_document, tenant:, plate: 'BBB2B22', issued_at: Time.zone.local(2026, 11, 2, 14), freight_cents: 70_000)
    create(:atua_transport_document, tenant:, plate: 'AAA1A11', issued_at: Time.zone.local(2026, 11, 3, 8), freight_cents: 25_000, canceled_at: Time.zone.local(2026, 11, 3, 9))
  end

  it 'sums the billing of each day by hour, counts the documents and classifies the day' do
    rows = described_class.call(tenant, tenant.billable_freights.by_plate('AAA1A11'), Date.new(2026, 11, 2)..Date.new(2026, 11, 3))

    expect(rows.map { it.slice(:date, :wday, :day_type, :billed_cents, :documents_count) }).to eq(
      [{ date: Date.new(2026, 11, 2), wday: 1, day_type: :weekday_holiday, billed_cents: 50_000, documents_count: 2 },
       { date: Date.new(2026, 11, 3), wday: 2, day_type: :regular, billed_cents: 0, documents_count: 0 }],
    )
    expect(rows.first[:hourly_cents].each_with_index.select { |cents, _| cents.positive? }).to eq([[40_000, 9], [10_000, 14]])
    expect(rows.pluck(:tenant_id).uniq).to eq([tenant.id])
  end

  it 'builds nothing without dates' do
    expect(described_class.call(tenant, tenant.billable_freights, [])).to eq([])
  end
end
