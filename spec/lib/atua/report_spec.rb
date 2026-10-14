require 'rails_helper'

RSpec.describe Atua::Report do
  describe '#periods' do
    it 'returns a single empty period for a report without period' do
      expect(described_class.find(:customers).periods(nil, nil)).to eq([[nil, nil]])
    end

    it 'refuses dates on a report without period' do
      expect { described_class.find(:vehicles).periods(Date.new(2026, 10, 1), nil) }
        .to raise_error(ArgumentError, 'O relatório vehicles não aceita período.')
    end

    it 'keeps a period shorter than 31 days in a single slice' do
      expect(described_class.find(:manifests).periods(Date.new(2026, 10, 1), Date.new(2026, 10, 13)))
        .to eq([[Date.new(2026, 10, 1), Date.new(2026, 10, 13)]])
    end

    it 'splits a longer period in monthly slices' do
      expect(described_class.find(:expenses).periods(Date.new(2026, 9, 15), Date.new(2026, 11, 2))).to eq(
        [
          [Date.new(2026, 9, 15), Date.new(2026, 9, 30)],
          [Date.new(2026, 10, 1), Date.new(2026, 10, 31)],
          [Date.new(2026, 11, 1), Date.new(2026, 11, 2)],
        ],
      )
    end

    it 'defaults the period to the current month through today' do
      travel_to Time.zone.local(2026, 10, 14, 9) do
        expect(described_class.find(:transport_documents).periods(nil, nil)).to eq([[Date.new(2026, 10, 1), Date.new(2026, 10, 14)]])
      end
    end

    it 'refuses a start date after the end date' do
      expect { described_class.find(:manifests).periods(Date.new(2026, 10, 2), Date.new(2026, 10, 1)) }
        .to raise_error(ArgumentError, 'A data inicial é posterior à data final.')
    end
  end
end
