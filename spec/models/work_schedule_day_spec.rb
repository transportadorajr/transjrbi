require 'rails_helper'

RSpec.describe WorkScheduleDay do
  let(:employee) { create(:employee) }

  describe 'validations' do
    it 'requires the reason of a leave' do
      day = build(:work_schedule_day, employee:, kind_type: 'leave')

      expect(day).not_to be_valid
      expect(day.errors.full_messages).to eq(['Motivo do afastamento não pode ficar em branco'])
    end

    it 'rejects a leave reason on a day off' do
      day = build(:work_schedule_day, employee:, leave_reason_type: 'medical_appointment')

      expect(day).not_to be_valid
      expect(day.errors.full_messages).to eq(['Motivo do afastamento deve ficar em branco'])
    end

    it 'rejects an unknown kind' do
      day = build(:work_schedule_day, employee:, kind_type: 'vacation')

      expect(day).not_to be_valid
      expect(day.errors.full_messages).to eq(['Tipo não está incluído na lista'])
    end

    it 'accepts a leave with its reason' do
      expect(build(:work_schedule_day, :leave, employee:)).to be_valid
    end

    context 'when the employee already has an entry on the date' do
      before { create(:work_schedule_day, employee:, date: Date.new(2026, 11, 24)) }

      it 'rejects a second entry on the same date' do
        day = build(:work_schedule_day, :leave, employee:, date: Date.new(2026, 11, 24))

        expect(day).not_to be_valid
        expect(day.errors.full_messages).to eq(['Data já está em uso'])
      end
    end
  end

  describe '.by_period' do
    let!(:inside) { create(:work_schedule_day, employee:, date: Date.new(2026, 11, 22)) }
    let!(:outside) { create(:work_schedule_day, employee:, date: Date.new(2026, 11, 29)) }

    it 'keeps only the entries of the dates' do
      expect(described_class.by_period(Date.new(2026, 11, 22)..Date.new(2026, 11, 28))).to eq([inside])
    end
  end
end
