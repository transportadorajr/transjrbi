require 'rails_helper'

RSpec.describe Holiday do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    let!(:black_consciousness) { create(:holiday, tenant:) }

    it 'requires a date unique by tenant and a name' do
      holiday = build(:holiday, tenant:, name: '')

      expect(holiday).not_to be_valid
      expect(holiday.errors.full_messages).to contain_exactly('Data já está em uso', 'Nome não pode ficar em branco')
    end

    it 'accepts the same date in another tenant' do
      expect(build(:holiday)).to be_valid
    end

    it 'rejects an unknown scope and kind' do
      holiday = build(:holiday, tenant:, date: Date.new(2026, 11, 2), scope_type: 'world', kind_type: 'party')

      expect(holiday).not_to be_valid
      expect(holiday.errors.full_messages).to contain_exactly('Abrangência não está incluído na lista', 'Tipo não está incluído na lista')
    end
  end

  describe 'enums' do
    it 'translates the scope and the kind' do
      holiday = build(:holiday, scope_type: 'municipal', kind_type: 'bridge_day')

      expect(holiday.scope_type_name).to eq('Municipal')
      expect(holiday.kind_type_name).to eq('Emenda')
    end
  end

  describe 'scopes' do
    let!(:christmas) { create(:holiday, tenant:, date: Date.new(2026, 12, 25), name: 'Natal') }
    let!(:new_year) { create(:holiday, tenant:, date: Date.new(2027, 1, 1), name: 'Confraternização Universal') }
    let!(:city_birthday) do
      create(:holiday, tenant:, date: Date.new(2026, 4, 29), name: 'Aniversário de Ipatinga', scope_type: 'municipal')
    end

    it 'filters by year' do
      expect(described_class.by_year('2026')).to contain_exactly(christmas, city_birthday)
    end

    it 'filters by name ignoring the case' do
      expect(described_class.by_name('natal')).to contain_exactly(christmas)
    end

    it 'filters by scope' do
      expect(described_class.by_scope_type('municipal')).to contain_exactly(city_birthday)
    end
  end
end
