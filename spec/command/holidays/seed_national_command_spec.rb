require 'rails_helper'

RSpec.describe Holidays::SeedNationalCommand do
  let(:tenant) { create(:tenant) }

  def holiday_rows(year)
    tenant.holidays.by_year(year).order(:date).map { |holiday| [holiday.date.iso8601, holiday.name, holiday.kind_type] }
  end

  describe '.easter' do
    it 'finds the easter sunday of each year' do
      expect((2024..2028).map { described_class.easter(it).iso8601 })
        .to eq(%w[2024-03-31 2025-04-20 2026-04-05 2027-03-28 2028-04-16])
    end
  end

  describe '.call' do
    it 'registers the national holidays, the optional days and the bridge days of the year' do
      expect { described_class.call(tenant, years: [2026]) }.to change(Holiday, :count).by(15)

      expect(holiday_rows(2026)).to eq(
        [
          ['2026-01-01', 'Confraternização Universal', 'holiday'],
          ['2026-01-02', 'Emenda de Confraternização Universal', 'bridge_day'],
          ['2026-02-16', 'Carnaval (segunda-feira)', 'optional'],
          ['2026-02-17', 'Carnaval (terça-feira)', 'optional'],
          ['2026-04-03', 'Sexta-feira Santa', 'holiday'],
          ['2026-04-20', 'Emenda de Tiradentes', 'bridge_day'],
          ['2026-04-21', 'Tiradentes', 'holiday'],
          ['2026-05-01', 'Dia do Trabalho', 'holiday'],
          ['2026-06-04', 'Corpus Christi', 'optional'],
          ['2026-09-07', 'Independência do Brasil', 'holiday'],
          ['2026-10-12', 'Nossa Senhora Aparecida', 'holiday'],
          ['2026-11-02', 'Finados', 'holiday'],
          ['2026-11-15', 'Proclamação da República', 'holiday'],
          ['2026-11-20', 'Dia Nacional de Zumbi e da Consciência Negra', 'holiday'],
          ['2026-12-25', 'Natal', 'holiday'],
        ],
      )
      expect(tenant.holidays.pluck(:scope_type).uniq).to eq(['national'])
    end

    it 'does not register the black consciousness day before it became a national holiday' do
      described_class.call(tenant, years: [2023])

      expect(tenant.holidays.by_name('Consciência Negra')).to be_empty
      expect(tenant.holidays.by_year(2023).count).to eq(15)
    end

    it 'registers the previous, the current and the next year by default' do
      travel_to(Time.zone.local(2026, 11, 11)) { described_class.call(tenant) }

      expect(tenant.holidays.pluck(Arel.sql('DISTINCT EXTRACT(YEAR FROM date)::integer')).sort).to eq([2025, 2026, 2027])
    end

    it 'returns the national holidays of the years' do
      result = described_class.call(tenant, years: [2026])

      expect(result.size).to eq(15)
      expect(result.first.date).to eq(Date.new(2026, 1, 1))
    end

    it 'does not duplicate the holidays when run again' do
      described_class.call(tenant, years: [2026])

      expect { described_class.call(tenant, years: [2026]) }.not_to change(Holiday, :count)
    end

    it 'keeps a national holiday removed by the user out of a year already registered' do
      described_class.call(tenant, years: [2026])
      tenant.holidays.find_by!(date: Date.new(2026, 6, 4)).destroy!

      expect { described_class.call(tenant, years: [2026]) }.not_to change(Holiday, :count)
      expect(tenant.holidays.exists?(date: Date.new(2026, 6, 4))).to be(false)
    end

    it 'keeps a municipal holiday registered on the same date' do
      city_holiday = create(:holiday, tenant:, date: Date.new(2026, 4, 20), name: 'Aniversário da cidade', scope_type: 'municipal')

      expect { described_class.call(tenant, years: [2026]) }.to change(Holiday, :count).by(14)

      expect(city_holiday.reload).to have_attributes(name: 'Aniversário da cidade', scope_type: 'municipal', kind_type: 'holiday')
    end

    it 'registers the holidays of each tenant apart' do
      other_tenant = create(:tenant)
      described_class.call(tenant, years: [2026])

      expect { described_class.call(other_tenant, years: [2026]) }.to change(Holiday, :count).by(15)
    end
  end
end
