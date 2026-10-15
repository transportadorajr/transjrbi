require 'rails_helper'

RSpec.describe Atua::Expense do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  describe 'associations' do
    context 'with the transport document, vehicle and payee of the tenant' do
      let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_750) }
      let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'UAV4A05') }
      let!(:payee) { create(:atua_customer, tenant:, code: 1951) }
      let!(:expense) do
        create(:atua_expense, tenant:, transport_document_code: 80_750, plate: 'UAV4A05', payee_code: 1951, cost_object: transport_document)
      end

      before do
        create(:atua_transport_document, tenant: other_tenant, code: 80_750)
        create(:atua_vehicle, tenant: other_tenant, plate: 'UAV4A05')
        create(:atua_customer, tenant: other_tenant, code: 1951)
      end

      it 'links the cost object the expense is allocated to' do
        expect(expense.cost_object).to eq(transport_document)
        expect(transport_document.expenses).to eq([expense])
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

    context 'with expenses allocated to freights, vehicles and the overhead' do
      let!(:truck) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
      let!(:trailer) { create(:atua_vehicle, tenant:, code: 813, plate: 'BEV4G50') }
      let!(:other_truck) { create(:atua_vehicle, tenant:, code: 900, plate: 'UAV4A05') }
      let!(:transport_document) do
        create(:atua_transport_document, tenant:, vehicle_code: 812, plate: 'EXU0F72', trailer_plate: 'BEV4G50')
      end
      let!(:toll) { create(:atua_expense, tenant:, plate: 'EXU0F72', total_cents: 15_000, cost_object: transport_document) }
      let!(:tire) { create(:atua_expense, tenant:, plate: 'EXU0F72', total_cents: 200_000, cost_object: truck) }
      let!(:other_tire) { create(:atua_expense, tenant:, plate: 'UAV4A05', total_cents: 180_000, cost_object: other_truck) }
      let!(:rent) { create(:atua_expense, tenant:, plate: nil, total_cents: 500_000) }

      it 'filters by allocation' do
        expect(described_class.by_allocation('freight')).to eq([toll])
        expect(described_class.by_allocation('vehicle')).to contain_exactly(tire, other_tire)
        expect(described_class.by_allocation('overhead')).to eq([rent])
        expect(described_class.count).to eq(4)
      end

      it 'ignores an unknown allocation' do
        expect(described_class.by_allocation('unknown')).to contain_exactly(toll, tire, other_tire, rent)
      end

      it 'filters by vehicle through its own expenses and the expenses of its freights' do
        expect(described_class.by_vehicle(truck)).to contain_exactly(toll, tire)
        expect(described_class.by_vehicle(trailer)).to eq([toll])
        expect(described_class.by_vehicle(other_truck)).to eq([other_tire])
      end

      it 'filters by plate through the freights pulled by the plate' do
        expect(described_class.by_plate('bev-4g50')).to eq([toll])
        expect(described_class.by_plate('EXU0F72')).to contain_exactly(toll, tire)
      end

      it 'sums the total of each allocation' do
        expect(described_class.total_by_allocation).to eq(
          'freight' => Money.from_cents(15_000),
          'vehicle' => Money.from_cents(380_000),
          'overhead' => Money.from_cents(500_000),
        )
      end

      it 'names the allocation of each expense' do
        expect([toll, tire, rent].map(&:allocation)).to eq(%w[freight vehicle overhead])
        expect([toll, tire, rent].map(&:allocation_name)).to eq(['Frete', 'Veículo', 'Despesa geral'])
      end
    end

    context 'with expenses of the transport documents carried by a manifest' do
      let!(:manifest) { create(:atua_manifest, tenant:, code: 41_236) }
      let!(:other_manifest) { create(:atua_manifest, tenant:, code: 41_237) }
      let!(:carried) { create(:atua_transport_document, tenant:, number: '74130') }
      let!(:also_carried) { create(:atua_transport_document, tenant:, number: '74131') }
      let!(:dropped) { create(:atua_transport_document, tenant:, number: '74132') }
      let!(:elsewhere) { create(:atua_transport_document, tenant:, number: '74133') }
      let!(:toll) { create(:atua_expense, tenant:, cost_object: carried) }
      let!(:unload) { create(:atua_expense, tenant:, cost_object: also_carried) }
      let!(:dropped_toll) { create(:atua_expense, tenant:, cost_object: dropped) }
      let!(:elsewhere_toll) { create(:atua_expense, tenant:, cost_object: elsewhere) }
      let!(:tire) { create(:atua_expense, tenant:, cost_object: create(:atua_vehicle, tenant:)) }

      before do
        create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130')
        create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74131')
        create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74132',
                                        removed_from_atua_at: Time.current)
        create(:atua_manifest_document, tenant:, manifest_code: 41_237, transport_document_number: '74133')
      end

      it 'filters by the freights still carried by the manifest' do
        expect(described_class.by_manifest(manifest)).to contain_exactly(toll, unload)
        expect(described_class.by_manifest(other_manifest)).to eq([elsewhere_toll])
        expect(described_class.count).to eq(5)
      end
    end

    context 'with the allocations offered by the filter' do
      it 'maps each translated allocation to its key' do
        expect(described_class.allocations).to eq('Frete' => 'freight', 'Veículo' => 'vehicle', 'Despesa geral' => 'overhead')
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
