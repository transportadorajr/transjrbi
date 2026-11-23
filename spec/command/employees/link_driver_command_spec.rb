require 'rails_helper'

RSpec.describe Employees::LinkDriverCommand do
  let(:tenant) { create(:tenant) }
  let(:employee) { create(:employee, tenant:, legal_id: '52998224725') }

  context 'when a transport document carries the CPF of the employee' do
    before do
      create(:atua_transport_document, tenant:, driver_code: 501, driver_document_digits: '52998224725',
                                       issued_at: Time.zone.local(2026, 9, 1))
      create(:atua_transport_document, tenant:, driver_code: 502, driver_document_digits: '52998224725',
                                       issued_at: Time.zone.local(2026, 10, 1))
      create(:atua_transport_document, driver_code: 999, driver_document_digits: '52998224725')
    end

    it 'links the driver of the latest document, creating it when missing' do
      expect { described_class.call(employee) }.to change(Driver, :count).by(1)

      expect(employee.reload.driver).to have_attributes(tenant:, code: 502)
    end

    it 'keeps the same link when run again' do
      described_class.call(employee)

      expect { described_class.call(employee) }.not_to change(Driver, :count)
      expect(employee.reload.driver_code).to eq(502)
    end

    context 'when the driver is already registered' do
      let!(:driver) { create(:driver, tenant:, code: 502) }

      it 'reuses the registered driver' do
        expect { described_class.call(employee) }.not_to change(Driver, :count)
        expect(employee.reload.driver).to eq(driver)
      end
    end

    context 'when the driver is linked to another employee' do
      let!(:other) { create(:employee, tenant:, legal_id: '11144477735', driver: create(:driver, tenant:, code: 502)) }

      it 'does not take the driver of another employee' do
        described_class.call(employee)

        expect(employee.reload.driver).to be_nil
        expect(other.reload.driver_code).to eq(502)
      end
    end
  end

  context 'when the employee has no CPF' do
    before do
      employee.update!(legal_id: nil)
      create(:atua_transport_document, tenant:, driver_code: 800, driver_document_digits: nil)
    end

    it 'does not link a driver of a document without CPF' do
      expect(described_class.call(employee)).to be_nil
      expect(employee.reload.driver).to be_nil
    end
  end

  context 'when no transport document carries the CPF' do
    before { employee.update!(driver: create(:driver, tenant:, code: 700)) }

    it 'removes a previous link' do
      expect(described_class.call(employee)).to be_nil
      expect(employee.reload.driver).to be_nil
    end
  end
end
