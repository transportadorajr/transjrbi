require 'rails_helper'

RSpec.describe WorkSchedules::SuggestCityCommand do
  let(:tenant) { create(:tenant) }
  let!(:driver) { create(:driver, tenant:, code: 501) }
  let!(:employee) { create(:employee, tenant:, driver:) }
  let!(:ipatinga) { create(:city, tenant:, name: 'Ipatinga', state: 'MG') }
  let!(:sao_paulo) { create(:city, tenant:, name: 'São Paulo', state: 'SP') }

  context 'when the employee has days off in several cities' do
    before do
      create(:work_schedule_day, employee:, date: Date.new(2026, 11, 1), city: sao_paulo)
      create(:work_schedule_day, employee:, date: Date.new(2026, 11, 2), city: ipatinga)
      create(:work_schedule_day, employee:, date: Date.new(2026, 11, 3), city: ipatinga)
      create(:work_schedule_day, :leave, employee:, date: Date.new(2026, 11, 4))
    end

    it 'suggests the city of most days off' do
      expect(described_class.call(employee)).to eq(ipatinga)
    end
  end

  context 'when the driver has no day off yet' do
    before do
      older = create(:atua_manifest, tenant:, closed_at: Time.zone.local(2026, 11, 10, 18))
      latest = create(:atua_manifest, tenant:, closed_at: Time.zone.local(2026, 11, 20, 18))
      [[older, 'IPATINGA', 'MG'], [latest, 'SAO PAULO', 'SP']].each do |manifest, city, state|
        transport_document = create(:atua_transport_document, tenant:, driver_code: 501, destination_city: city, destination_state: state)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number,
                                        destination_city: city, destination_state: state)
      end
    end

    it 'suggests the final destination of the last closed trip' do
      expect(described_class.call(employee)).to eq(sao_paulo)
    end
  end

  context 'when there is nothing to suggest from' do
    it 'suggests no city' do
      expect(described_class.call(employee)).to be_nil
    end
  end
end
