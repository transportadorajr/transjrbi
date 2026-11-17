require 'rails_helper'

RSpec.describe MaintenancePartMovement do
  let(:part) { create(:maintenance_part) }
  let!(:entry) { create(:maintenance_part_movement, maintenance_part: part, movement_type: :entry, moved_on: Date.new(2026, 11, 10)) }
  let!(:adjustment) do
    create(:maintenance_part_movement, maintenance_part: part, movement_type: :adjustment, moved_on: Date.new(2026, 11, 15))
  end
  let!(:other) { create(:maintenance_part_movement, movement_type: :exit, moved_on: Date.new(2026, 11, 12)) }

  it 'filters the movements by part, type and period' do
    expect(described_class.by_maintenance_part(part.id)).to contain_exactly(entry, adjustment)
    expect(described_class.by_movement_type('adjustment')).to contain_exactly(adjustment)
    expect(described_class.by_movement_type('unknown')).to contain_exactly(entry, adjustment, other)
    expect(described_class.by_period_start(Date.new(2026, 11, 12)).by_period_end(Date.new(2026, 11, 14))).to contain_exactly(other)
  end

  it 'validates the movement type' do
    expect(build(:maintenance_part_movement, movement_type: 'loan')).not_to be_valid
  end
end
