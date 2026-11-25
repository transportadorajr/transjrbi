require 'rails_helper'

RSpec.describe VacationForm do
  let(:tenant) { create(:tenant) }
  let!(:employee) { create(:employee, tenant:, admitted_on: Date.new(2024, 3, 10)) }

  def build_form(start_on:, end_on:, sold_days: 0, employee_id: employee.id)
    described_class.new(tenant:, employee_id:, start_on:, end_on:, sold_days:)
  end

  describe '#save' do
    it 'creates the vacation in the oldest period with balance' do
      form = described_class.new(tenant:, employee_id: employee.id, start_on: '2025-04-01', end_on: '2025-04-20', sold_days: 10,
                                 notes: '  venda  de 10 dias ')

      expect { expect(form.save).to be(true) }.to change(Vacation, :count).by(1)
      expect(Vacation.last).to have_attributes(tenant:, employee:, acquisition_start_on: Date.new(2024, 3, 10), start_on: Date.new(2025, 4, 1),
                                               end_on: Date.new(2025, 4, 20), sold_days: 10, notes: 'venda de 10 dias')
    end

    it 'moves to the next period once the oldest one has no balance' do
      create(:vacation, employee:, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 30))

      form = build_form(start_on: Date.new(2026, 4, 1), end_on: Date.new(2026, 4, 30))

      expect(form.save).to be(true)
      expect(Vacation.last.acquisition_start_on).to eq(Date.new(2025, 3, 10))
    end

    it 'skips the periods that ended more than two years before the vacation' do
      employee.update!(admitted_on: Date.new(2020, 3, 10))

      expect(build_form(start_on: '2026-04-01', end_on: '2026-04-20').save).to be(true)
      expect(Vacation.last.acquisition_start_on).to eq(Date.new(2024, 3, 10))
    end

    it 'updates a vacation keeping its period' do
      vacation = create(:vacation, employee:, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 30))
      form = described_class.for_vacation(vacation)
      form.assign_attributes(start_on: Date.new(2025, 5, 1), end_on: Date.new(2025, 5, 20), sold_days: 10)

      expect { expect(form.save).to be(true) }.not_to change(Vacation, :count)
      expect(vacation.reload).to have_attributes(acquisition_start_on: Date.new(2024, 3, 10), start_on: Date.new(2025, 5, 1),
                                                 end_on: Date.new(2025, 5, 20), sold_days: 10)
    end
  end

  describe 'validations' do
    it 'requires an employee with an admission date' do
      employee.update!(admitted_on: nil)

      form = build_form(start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 30))

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(
        ['Funcionário precisa ter a data de admissão cadastrada para calcular o período aquisitivo'],
      )
    end

    it 'rejects a period that ends before it starts or is shorter than 5 days' do
      backwards = build_form(start_on: Date.new(2025, 4, 10), end_on: Date.new(2025, 4, 1))
      too_short = build_form(start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 4))

      expect([backwards.valid?, too_short.valid?]).to all(be(false))
      expect(backwards.errors.full_messages).to eq(['Último dia de férias deve ser igual ou posterior à saída'])
      expect(too_short.errors.full_messages).to eq(['Último dia de férias deve deixar pelo menos 5 dias de férias'])
    end

    it 'rejects more than 10 sold days' do
      form = build_form(start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 19), sold_days: 11)

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Dias vendidos deve ser menor ou igual a 10'])
    end

    it 'rejects a vacation before the period is acquired' do
      form = build_form(start_on: Date.new(2025, 2, 1), end_on: Date.new(2025, 2, 20))

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Saída cai antes de completar o período aquisitivo: só a partir de 10/03/2025'])
    end

    context 'when part of the period was already taken' do
      before { create(:vacation, employee:, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 14), sold_days: 6) }

      it 'rejects days beyond the balance' do
        form = build_form(start_on: Date.new(2025, 7, 1), end_on: Date.new(2025, 7, 12))

        expect(form).not_to be_valid
        expect(form.errors.full_messages).to eq(
          ['Último dia de férias passa do saldo do período aquisitivo 10/03/2024 a 09/03/2025: restam 10 dias, contando os vendidos'],
        )
      end

      it 'rejects sold days beyond the limit of the period' do
        form = build_form(start_on: Date.new(2025, 7, 1), end_on: Date.new(2025, 7, 5), sold_days: 5)

        expect(form).not_to be_valid
        expect(form.errors.full_messages).to eq(['Dias vendidos passa do limite de venda do período aquisitivo: restam 4 dias'])
      end

      it 'accepts the rest of the balance in a second part' do
        expect(build_form(start_on: Date.new(2025, 7, 1), end_on: Date.new(2025, 7, 10))).to be_valid
      end
    end

    it 'rejects a fourth part in the same period' do
      create(:vacation, employee:, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 14))
      create(:vacation, employee:, start_on: Date.new(2025, 6, 1), end_on: Date.new(2025, 6, 5))
      create(:vacation, employee:, start_on: Date.new(2025, 8, 1), end_on: Date.new(2025, 8, 5))

      form = build_form(start_on: Date.new(2025, 10, 1), end_on: Date.new(2025, 10, 6))

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Saída já tem 3 períodos de férias lançados no período aquisitivo'])
    end

    it 'keeps room for a part of at least 14 days when the vacation is split' do
      first = build_form(start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 10), sold_days: 10)

      expect(first).not_to be_valid
      expect(first.errors.full_messages).to eq(
        ['Último dia de férias não deixa espaço para um período de pelo menos 14 dias, obrigatório quando as férias são divididas'],
      )
    end

    it 'rejects a vacation that overlaps another one' do
      create(:vacation, employee:, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 14))

      form = build_form(start_on: Date.new(2025, 4, 10), end_on: Date.new(2025, 4, 25))

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Saída já tem férias lançadas em: 01/04/2025 a 14/04/2025'])
    end

    it 'rejects days already entered on the work schedule' do
      create(:work_schedule_day, employee:, date: Date.new(2025, 4, 5))

      form = build_form(start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 30))

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Saída já tem folga ou afastamento na escala em: 05/04/2025'])
    end

    context 'when the employee is a driver on a trip' do
      let!(:driver) { create(:driver, tenant:, code: 501) }

      before do
        employee.update!(driver:)
        manifest = create(:atua_manifest, tenant:, trip_started_at: Time.zone.local(2025, 4, 2, 8), closed_at: Time.zone.local(2025, 4, 3, 18))
        transport_document = create(:atua_transport_document, tenant:, driver_code: 501)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
      end

      it 'rejects the days of the trip' do
        form = build_form(start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 30))

        expect(form).not_to be_valid
        expect(form.errors.full_messages).to eq(['Saída cai em dia de viagem do motorista: 02/04/2025 e 03/04/2025'])
      end
    end

    it 'rejects an employee of another tenant' do
      stranger = create(:employee, admitted_on: Date.new(2024, 3, 10))

      form = build_form(start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 30), employee_id: stranger.id)

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Funcionário não pode ficar em branco'])
    end
  end
end
