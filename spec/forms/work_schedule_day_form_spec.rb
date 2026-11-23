require 'rails_helper'

RSpec.describe WorkScheduleDayForm do
  let(:tenant) { create(:tenant) }
  let!(:driver) { create(:driver, tenant:, code: 501) }
  let!(:employee) { create(:employee, tenant:, driver:) }
  let!(:ipatinga) { create(:city, tenant:, name: 'Ipatinga', state: 'MG', base: true) }

  describe '#save' do
    it 'creates a day off in the city' do
      form = described_class.new(tenant:, employee_id: employee.id, kind_type: 'day_off', start_on: '2026-11-25',
                                 city_id: ipatinga.id, notes: '  folga  combinada ')

      expect { expect(form.save).to be(true) }.to change(WorkScheduleDay, :count).by(1)
      expect(WorkScheduleDay.last).to have_attributes(
        tenant:, employee:, date: Date.new(2026, 11, 25), kind_type: 'day_off', city: ipatinga, leave_reason_type: nil,
        notes: 'folga combinada'
      )
    end

    it 'creates a leave for every day of the period without a city' do
      form = described_class.new(tenant:, employee_id: employee.id, kind_type: 'leave', start_on: '2026-11-23', end_on: '2026-11-25',
                                 leave_reason_type: 'medical_certificate', city_id: ipatinga.id)

      expect { expect(form.save).to be(true) }.to change(WorkScheduleDay, :count).by(3)
      expect(WorkScheduleDay.order(:date).pluck(:date, :kind_type, :leave_reason_type, :city_id)).to eq(
        [
          [Date.new(2026, 11, 23), 'leave', 'medical_certificate', nil],
          [Date.new(2026, 11, 24), 'leave', 'medical_certificate', nil],
          [Date.new(2026, 11, 25), 'leave', 'medical_certificate', nil],
        ],
      )
    end

    it 'requires the city of a day off and the reason of a leave' do
      day_off = described_class.new(tenant:, employee_id: employee.id, kind_type: 'day_off', start_on: '2026-11-25')
      leave = described_class.new(tenant:, employee_id: employee.id, kind_type: 'leave', start_on: '2026-11-25')

      expect([day_off.save, leave.save]).to all(be_falsey)
      expect(day_off.errors.full_messages).to eq(['Cidade da folga não pode ficar em branco'])
      expect(leave.errors.full_messages).to eq(['Motivo do afastamento não pode ficar em branco'])
    end

    it 'rejects a period that ends before it starts or is too long' do
      backwards = described_class.new(tenant:, employee_id: employee.id, kind_type: 'day_off', start_on: '2026-11-25',
                                      end_on: '2026-11-24', city_id: ipatinga.id)
      too_long = described_class.new(tenant:, employee_id: employee.id, kind_type: 'leave', start_on: '2026-11-01',
                                     end_on: '2026-12-15', leave_reason_type: 'medical_certificate')

      expect([backwards.save, too_long.save]).to all(be_falsey)
      expect(backwards.errors.full_messages).to eq(['Até deve ser igual ou posterior à data inicial'])
      expect(too_long.errors.full_messages).to eq(['Até não pode passar de 31 dias'])
    end

    context 'when the employee and the city belong to another tenant' do
      let!(:stranger) { create(:employee) }
      let!(:stranger_city) { create(:city) }

      it 'rejects an employee or a city of another tenant' do
        form = described_class.new(tenant:, employee_id: stranger.id, kind_type: 'day_off', start_on: '2026-11-25',
                                   city_id: stranger_city.id)

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to contain_exactly('Funcionário não pode ficar em branco', 'Cidade da folga não é válido')
      end
    end

    context 'when the employee already has an entry in the period' do
      before { create(:work_schedule_day, employee:, date: Date.new(2026, 11, 24), city: ipatinga) }

      it 'rejects the dates already taken' do
        form = described_class.new(tenant:, employee_id: employee.id, kind_type: 'leave', start_on: '2026-11-23', end_on: '2026-11-25',
                                   leave_reason_type: 'medical_appointment')

        expect { expect(form.save).to be_falsey }.not_to change(WorkScheduleDay, :count)
        expect(form.errors.full_messages).to eq(['De já tem lançamento em: 24/11/2026'])
      end
    end

    context 'when the driver is on a trip' do
      before do
        manifest = create(:atua_manifest, tenant:, trip_started_at: Time.zone.local(2026, 11, 20, 8), closed_at: Time.zone.local(2026, 11, 24, 18))
        transport_document = create(:atua_transport_document, tenant:, driver_code: 501)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
      end

      it 'blocks a day off on the trip days' do
        form = described_class.new(tenant:, employee_id: employee.id, kind_type: 'day_off', start_on: '2026-11-23', end_on: '2026-11-25',
                                   city_id: ipatinga.id)

        expect { expect(form.save).to be_falsey }.not_to change(WorkScheduleDay, :count)
        expect(form.errors.full_messages).to eq(['De cai em dia de viagem do motorista: 23/11/2026 e 24/11/2026'])
      end

      it 'accepts a leave on the trip days' do
        form = described_class.new(tenant:, employee_id: employee.id, kind_type: 'leave', start_on: '2026-11-23',
                                   leave_reason_type: 'medical_certificate')

        expect(form.save).to be(true)
      end

      it 'accepts a day off after the trip' do
        form = described_class.new(tenant:, employee_id: employee.id, kind_type: 'day_off', start_on: '2026-11-25', city_id: ipatinga.id)

        expect(form.save).to be(true)
      end
    end
  end

  describe '.for_employee' do
    context 'when the employee has taken days off before' do
      before do
        create(:work_schedule_day, employee:, date: Date.new(2026, 11, 1), city: ipatinga)
        create(:work_schedule_day, employee:, date: Date.new(2026, 11, 2), city: ipatinga)
        create(:work_schedule_day, employee:, date: Date.new(2026, 11, 8), city: create(:city, tenant:, name: 'Betim'))
      end

      it 'suggests the city where the employee took the most days off' do
        form = described_class.for_employee(tenant, employee, Date.new(2026, 11, 25))

        expect(form).to have_attributes(employee_id: employee.id, kind_type: 'day_off', start_on: Date.new(2026, 11, 25),
                                        end_on: Date.new(2026, 11, 25), city_id: ipatinga.id)
      end
    end
  end
end
