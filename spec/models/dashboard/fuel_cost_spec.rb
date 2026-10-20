require 'rails_helper'

RSpec.describe Dashboard::FuelCost do
  subject(:fuel_cost) { described_class.new(tenant.atua_expenses, manifests: tenant.atua_manifests, until_on: Date.new(2026, 10, 31)) }

  let!(:tenant) { create(:tenant) }

  it 'averages the twelve months up to the end of the period' do
    expect(fuel_cost.period).to eq(Date.new(2025, 11, 1)..Date.new(2026, 10, 31))
  end

  context 'with the trips and the fuel of the trucks in the last twelve months' do
    before do
      create(:atua_manifest, tenant:, code: 41_001, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8))
      create(:atua_manifest, tenant:, code: 41_002, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 3, 10, 8))
      create(:atua_manifest, tenant:, code: 41_003, plate: 'RVR2C34', trip_started_at: Time.zone.local(2025, 10, 20, 8))
      create(:atua_manifest, tenant:, code: 41_004, plate: 'RVR2C34', status: 'Cancelado', trip_started_at: Time.zone.local(2026, 5, 4))
      create(:atua_manifest, tenant:, code: 41_005, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 6, 1, 8))
      create(:atua_manifest_document, tenant:, manifest_code: 41_001, calculated_distance_km: 450, document_distance_km: 480)
      create(:atua_manifest_document, tenant:, manifest_code: 41_001, calculated_distance_km: 500, document_distance_km: nil)
      create(:atua_manifest_document, tenant:, manifest_code: 41_002, calculated_distance_km: 400)
      create(:atua_manifest_document, tenant:, manifest_code: 41_003, calculated_distance_km: 1_000)
      create(:atua_manifest_document, tenant:, manifest_code: 41_004, calculated_distance_km: 300)
      create(:atua_manifest_document, tenant:, manifest_code: 41_005, calculated_distance_km: 200)
      create(:empty_leg, tenant:, plate: 'RVR2C34', previous_manifest_code: 41_002, next_manifest_code: 41_001, distance_km: 100)
      create(:empty_leg, tenant:, plate: 'RVR2C34', previous_manifest_code: 41_003, next_manifest_code: 41_002,
                         status_type: 'unrouted', distance_km: nil)

      create(:atua_expense, tenant:, plate: 'RVR2C34', history_code: 11, document_on: Date.new(2026, 10, 1), total_cents: 200_000)
      create(:atua_expense, tenant:, plate: 'RVR2C34', history_code: 396, document_on: Date.new(2026, 3, 9), total_cents: 50_000)
      create(:atua_expense, tenant:, plate: 'RVR2C34', history_code: 56, document_on: Date.new(2026, 4, 1), total_cents: 99_000)
      create(:atua_expense, tenant:, plate: 'RVR2C34', history_code: 11, document_on: Date.new(2025, 10, 31),
                            posted_on: Date.new(2025, 11, 2), total_cents: 70_000)
      create(:atua_expense, tenant:, plate: 'RVR2C34', history_code: 11, document_on: Date.new(2026, 8, 1), total_cents: 60_000,
                            removed_from_atua_at: Time.current)
      create(:atua_expense, tenant:, plate: 'RVR7H89', history_code: 11, document_on: Date.new(2026, 8, 1), total_cents: 40_000)

      other_tenant = create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra')
      create(:atua_expense, tenant: other_tenant, plate: 'RVR2C34', history_code: 11, document_on: Date.new(2026, 8, 1),
                            total_cents: 500_000)
    end

    it 'divides the diesel and arla of each plate by the loaded and calculated empty km of its trips' do
      expect(Atua::Expense.count).to eq(7)
      expect(fuel_cost.rate_for('RVR2C34')).to eq(BigDecimal('250'))
    end

    it 'charges nothing per km to a plate whose trips have no fuel or that has no trips' do
      expect(fuel_cost.rate_for('RVR8J90')).to eq(BigDecimal('0'))
      expect(fuel_cost.rate_for('RVR7H89')).to eq(BigDecimal('0'))
    end

    it 'multiplies the km of a trip by the rate of its plate' do
      expect(fuel_cost.cents_for('RVR2C34', BigDecimal('100'), 'Próprio')).to eq(25_000)
      expect(fuel_cost.cents_for('RVR2C34', BigDecimal('33.33'), nil)).to eq(8_333)
    end

    it 'charges no fuel to third party and aggregated vehicles' do
      expect(fuel_cost.cents_for('RVR2C34', BigDecimal('100'), 'Terceiro')).to eq(0)
      expect(fuel_cost.cents_for('RVR2C34', BigDecimal('100'), 'Agregado')).to eq(0)
    end
  end
end
