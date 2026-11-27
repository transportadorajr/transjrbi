require 'rails_helper'

RSpec.describe FreightBillingsHelper do
  def freight_row(empty_share:, awaiting_manifest:)
    zero = Money.from_cents(0)

    Dashboard::Freight::Row.new(key: 'RVR5A33', label: 'RVR5A33', trips_count: 0, loaded_km: 0, empty_km: nil, empty_share:, gross: zero,
                                freight_expenses: zero, expenses: zero, toll: zero, undiscounted_toll: zero, net: zero, gross_per_km: nil,
                                net_per_km: nil, share: 0, previous_gross: nil, awaiting_manifest:)
  end

  describe '#freight_billing_empty_share' do
    it 'shows the empty share of the measured trips' do
      expect(helper.freight_billing_empty_share(freight_row(empty_share: BigDecimal('15.4'), awaiting_manifest: true))).to eq('15,4%')
    end

    it 'shows that the row awaits its MDF-e when no trip was measured' do
      expect(helper.freight_billing_empty_share(freight_row(empty_share: nil, awaiting_manifest: true))).to eq('Aguardando MDF-e')
    end

    it 'shows a dash for a row that never gets an MDF-e' do
      expect(helper.freight_billing_empty_share(freight_row(empty_share: nil, awaiting_manifest: false))).to eq('-')
    end
  end

  describe '#freight_billing_empty_share_status' do
    it 'tells only the rows awaiting their MDF-e' do
      expect(helper.freight_billing_empty_share_status(freight_row(empty_share: nil, awaiting_manifest: true))).to eq('Aguardando MDF-e')
      expect(helper.freight_billing_empty_share_status(freight_row(empty_share: BigDecimal('0'), awaiting_manifest: true))).to be_nil
      expect(helper.freight_billing_empty_share_status(freight_row(empty_share: nil, awaiting_manifest: false))).to be_nil
    end
  end

  describe '#freight_billing_km' do
    it 'shows a dash for a distance that was not measured' do
      expect(helper.freight_billing_km(nil)).to eq('-')
      expect(helper.freight_billing_km(BigDecimal('1234.6'))).to eq('1.235 km')
    end
  end
end
