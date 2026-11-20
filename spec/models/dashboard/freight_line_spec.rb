require 'rails_helper'

RSpec.describe Dashboard::FreightLine do
  let!(:tenant) { create(:tenant) }
  let!(:measured_document) { create(:atua_transport_document, tenant:, number: '74001', freight_cents: 1_000_000) }
  let!(:short_document) { create(:atua_transport_document, tenant:, number: '74002', freight_cents: 300_000) }
  let!(:unmeasured_document) { create(:atua_transport_document, tenant:, number: '74003', freight_cents: 500_000) }
  let(:measured) { line_of(measured_document, BigDecimal('300')) }
  let(:short) { line_of(short_document, BigDecimal('100')) }
  let(:unmeasured) { line_of(unmeasured_document, nil) }

  def line_of(document, loaded_km)
    described_class.new(transport_document: Atua::TransportDocument.with_freight_totals.find(document.id), loaded_km:)
  end

  it 'divides the gross and the net freight of the document by its km' do
    expect(measured).to be_measured
    expect(measured.gross_per_km).to eq(Money.from_cents(3_333))
    expect(measured.net_per_km).to eq(Money.from_cents(3_333))
  end

  it 'has no freight per km without km' do
    expect(unmeasured).not_to be_measured
    expect(unmeasured.gross_per_km).to be_nil
    expect(line_of(unmeasured_document, BigDecimal('0')).net_per_km).to be_nil
  end

  it 'sums the freight per km of the lines with km, leaving the others out' do
    expect(Atua::TransportDocument.count).to eq(3)
    expect(described_class.gross_per_km([measured, short, unmeasured])).to eq(Money.from_cents(3_250))
    expect(described_class.net_per_km([measured, short, unmeasured])).to eq(Money.from_cents(3_250))
    expect(described_class.gross_per_km([unmeasured])).to be_nil
  end
end
