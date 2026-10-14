require 'rails_helper'

RSpec.describe Atua::Expense do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  describe 'associations' do
    context 'with the transport document, vehicle and payee of the tenant' do
      let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_750) }
      let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'UAV4A05') }
      let!(:payee) { create(:atua_customer, tenant:, code: 1951) }
      let!(:expense) { create(:atua_expense, tenant:, transport_document_code: 80_750, plate: 'UAV4A05', payee_code: 1951) }

      before do
        create(:atua_transport_document, tenant: other_tenant, code: 80_750)
        create(:atua_vehicle, tenant: other_tenant, plate: 'UAV4A05')
        create(:atua_customer, tenant: other_tenant, code: 1951)
      end

      it 'links the transport document by code inside the tenant' do
        expect(expense.transport_document).to eq(transport_document)
      end

      it 'links the vehicle by plate inside the tenant' do
        expect(expense.vehicle).to eq(vehicle)
      end

      it 'links the payee by code inside the tenant' do
        expect(expense.payee).to eq(payee)
        expect(Atua::Customer.count).to eq(2)
      end
    end
  end

  describe 'validations' do
    context 'with an expense already imported' do
      let!(:expense) { create(:atua_expense, tenant:, code: 590_252) }

      it 'rejects the same code in the same tenant' do
        duplicated = build(:atua_expense, tenant:, code: 590_252)

        expect(duplicated).not_to be_valid
        expect(duplicated.errors[:code]).to eq(['já está em uso'])
      end

      it 'accepts the same code in another tenant' do
        expect(build(:atua_expense, tenant: other_tenant, code: expense.code)).to be_valid
      end
    end
  end

  describe 'money' do
    it 'exposes the cents columns as reais' do
      expense = build(:atua_expense, total_cents: 725_000, icms_credit_cents: nil)

      expect(expense.total).to eq(Money.from_cents(725_000, 'BRL'))
      expect(expense.icms_credit).to be_nil
    end
  end

  describe 'scopes' do
    context 'with expenses of different periods, companies and classifications' do
      let!(:fuel) do
        create(:atua_expense, tenant:, posted_on: Date.new(2026, 10, 1), plate: 'UAV4A05', history_code: 10, payee_code: 1951,
                              trip_number: '2500653', branch_code: 2189, headquarters_name: 'JR TRANSPORTES')
      end
      let!(:unload) do
        create(:atua_expense, tenant:, posted_on: Date.new(2026, 10, 13), plate: 'EXU0F72', history_code: 20, payee_code: 1951,
                              branch_code: 8042, headquarters_name: 'MME TRANSPORTES')
      end
      let!(:outside) do
        create(:atua_expense, tenant:, posted_on: Date.new(2026, 9, 30), plate: 'UAV4A05', history_code: 10, payee_code: 7000,
                              branch_code: 2189, headquarters_name: 'MM ESPINOLA')
      end
      let!(:removed) do
        create(:atua_expense, tenant:, posted_on: Date.new(2026, 10, 5), history_code: 30, removed_from_atua_at: Time.current,
                              headquarters_name: 'JR TRANSPORTES')
      end

      it 'filters by the posting period' do
        expect(described_class.by_period('2026-10-01', '2026-10-13')).to contain_exactly(fuel, unload, removed)
        expect(described_class.count).to eq(4)
      end

      it 'filters by plate' do
        expect(described_class.by_plate('uav4a05')).to contain_exactly(fuel, outside)
      end

      it 'filters by the expense history' do
        expect(described_class.by_history(10)).to contain_exactly(fuel, outside)
      end

      it 'filters by payee and trip' do
        expect(described_class.by_payee(1951)).to contain_exactly(fuel, unload)
        expect(described_class.by_trip('2500653')).to eq([fuel])
      end

      it 'filters by headquarters and branch' do
        expect(described_class.by_headquarters('JR TRANSPORTES')).to contain_exactly(fuel, removed)
        expect(described_class.by_branch(2189)).to contain_exactly(fuel, outside)
      end

      it 'keeps out expenses removed from Atua' do
        expect(described_class.active).to contain_exactly(fuel, unload, outside)
      end

      it 'filters by the start and the end of the posting period separately' do
        expect(described_class.by_period_start('2026-10-05')).to contain_exactly(unload, removed)
        expect(described_class.by_period_end('2026-10-01')).to contain_exactly(fuel, outside)
      end
    end

    context 'with expenses of different payees' do
      let!(:gas_station) { create(:atua_expense, tenant:, payee_name: 'POSTO TREVO LTDA') }
      let!(:loader) { create(:atua_expense, tenant:, payee_name: 'CHAPA 100% LTDA') }

      before { create(:atua_expense, tenant:, payee_name: nil) }

      it 'filters by the payee name ignoring case' do
        expect(described_class.by_payee_name(' trevo ')).to eq([gas_station])
        expect(described_class.count).to eq(3)
      end

      it 'treats the LIKE wildcards of the payee name literally' do
        expect(described_class.by_payee_name('100%')).to eq([loader])
        expect(described_class.by_payee_name('%')).to eq([loader])
      end
    end
  end
end
