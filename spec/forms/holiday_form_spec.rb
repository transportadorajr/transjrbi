require 'rails_helper'

RSpec.describe HolidayForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    it 'creates a holiday of the tenant' do
      form = described_class.new(tenant:, date: '2026-04-29', name: ' Aniversário de  Ipatinga ', scope_type: 'municipal',
                                 kind_type: 'holiday')

      expect { expect(form.save).to be(true) }.to change(Holiday, :count).by(1)

      expect(Holiday.last).to have_attributes(tenant:, date: Date.new(2026, 4, 29), name: 'Aniversário de Ipatinga',
                                              scope_type: 'municipal', kind_type: 'holiday')
    end

    it 'creates a national holiday by default' do
      form = described_class.new(tenant:, date: '2026-11-20', name: 'Consciência Negra')

      expect(form.save).to be(true)
      expect(Holiday.last).to have_attributes(scope_type: 'national', kind_type: 'holiday')
    end

    it 'rejects a holiday without the required fields' do
      form = described_class.new(tenant:, name: ' ', scope_type: 'world', kind_type: '')

      expect { expect(form.save).to be_falsey }.not_to change(Holiday, :count)
      expect(form.errors.full_messages).to contain_exactly('Data não pode ficar em branco', 'Nome não pode ficar em branco',
                                                           'Abrangência não está incluído na lista',
                                                           'Tipo não pode ficar em branco')
    end

    context 'when the date already has a holiday' do
      let!(:black_consciousness) { create(:holiday, tenant:) }

      it 'rejects another holiday on the same date' do
        form = described_class.new(tenant:, date: '2026-11-20', name: 'Outro feriado')

        expect { expect(form.save).to be_falsey }.not_to change(Holiday, :count)
        expect(form.errors.full_messages).to eq(['Data já tem um feriado cadastrado'])
      end

      it 'accepts the same date in another tenant' do
        form = described_class.new(tenant: create(:tenant), date: '2026-11-20', name: 'Consciência Negra')

        expect { expect(form.save).to be(true) }.to change(Holiday, :count).by(1)
      end

      it 'updates the holiday keeping its own date' do
        form = described_class.for_holiday(black_consciousness)
        form.assign_attributes(name: 'Consciência Negra', scope_type: 'state', kind_type: 'optional')

        expect { expect(form.save).to be(true) }.not_to change(Holiday, :count)
        expect(black_consciousness.reload).to have_attributes(date: Date.new(2026, 11, 20), name: 'Consciência Negra',
                                                              scope_type: 'state', kind_type: 'optional')
      end
    end
  end
end
