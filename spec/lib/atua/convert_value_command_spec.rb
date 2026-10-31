require 'rails_helper'

RSpec.describe Atua::ConvertValueCommand do
  let(:tenant) { build(:tenant) }
  let(:time_zone) { ActiveSupport::TimeZone['America/Sao_Paulo'] }

  def convert(value, type, **)
    described_class.call(tenant, value, type, **)
  end

  describe 'string' do
    it 'strips the text and turns blank into nil' do
      expect(convert(' 31261091025477000349570010000003971521192668 ', :string)).to eq('31261091025477000349570010000003971521192668')
      expect(convert('5200357883199946  ', :string)).to eq('5200357883199946')
      expect(convert('   ', :string)).to be_nil
      expect(convert(nil, :string)).to be_nil
    end

    it 'keeps the leading zeros of a text and drops the .0 of a whole number' do
      expect(convert('00', :string)).to eq('00')
      expect(convert('00661093581', :string)).to eq('00661093581')
      expect(convert(41.0, :string)).to eq('41')
      expect(convert(2_082_496.0, :string)).to eq('2082496')
      expect(convert(2.5, :string)).to eq('2.5')
    end

    it 'pads a number that lost its leading zeros' do
      expect(convert(946_524_790.0, :string, pad: 11)).to eq('00946524790')
      expect(convert(1_234_567.0, :string, pad: 8)).to eq('01234567')
      expect(convert('85.815-150', :string, pad: 8)).to eq('85.815-150')
    end
  end

  describe 'integer' do
    it 'converts a float or a text into an integer' do
      expect(convert(80_842.0, :integer)).to eq(80_842)
      expect(convert('01', :integer)).to eq(1)
      expect(convert(' 74081 ', :integer)).to eq(74_081)
      expect(convert('74081.0', :integer)).to eq(74_081)
      expect(convert('', :integer)).to be_nil
    end

    it 'refuses a fraction or a text that is not a number' do
      expect { convert(1.5, :integer) }.to raise_error(Atua::ConversionError, 'o valor 1.5 não pode ser convertido para integer.')
      expect { convert('Não Cobrado', :integer) }.to raise_error(Atua::ConversionError)
    end
  end

  describe 'cents' do
    it 'converts a float through BigDecimal rounding half up' do
      expect(convert(555.04, :cents)).to eq(55_504)
      expect(convert(516.1877162236675, :cents)).to eq(51_619)
      expect(convert(1.005, :cents)).to eq(101)
      expect(convert(0.0, :cents)).to eq(0)
      expect(convert(-12.5, :cents)).to eq(-1250)
      expect(convert(nil, :cents)).to be_nil
    end

    it 'converts a brazilian formatted text' do
      expect(convert('1.234,56', :cents)).to eq(123_456)
      expect(convert('R$ 7.250,00', :cents)).to eq(725_000)
      expect(convert('1.234', :cents)).to eq(123_400)
      expect(convert('393.74', :cents)).to eq(39_374)
    end

    it 'refuses a text that is not an amount' do
      expect { convert('Kg x R$ 4.5386', :cents) }.to raise_error(Atua::ConversionError)
    end
  end

  describe 'decimal' do
    it 'converts weights, distances and percentages without float noise' do
      expect(convert(1.917, :decimal)).to eq(BigDecimal('1.917'))
      expect(convert(1705.5882704081196, :decimal)).to eq(BigDecimal('1705.5882704081196'))
      expect(convert(83.75, :decimal)).to eq(BigDecimal('83.75'))
      expect(convert('8,043', :decimal)).to eq(BigDecimal('8.043'))
      expect(convert(nil, :decimal)).to be_nil
    end
  end

  describe 'list' do
    it 'splits a comma separated text' do
      expect(convert('40798, 40834', :list)).to eq(%w[40798 40834])
      expect(convert('40798, 40834', :list, of: :integer)).to eq([40_798, 40_834])
      expect(convert('4199237, 4197775, 4199241 ', :list)).to eq(%w[4199237 4197775 4199241])
    end

    it 'turns a single number into a one item list' do
      expect(convert(183.0, :list, of: :integer)).to eq([183])
      expect(convert(2_082_496.0, :list)).to eq(%w[2082496])
    end

    it 'accepts another separator' do
      expect(convert('a@exemplo.com.br;b@exemplo.com.br', :list, separator: ';')).to eq(%w[a@exemplo.com.br b@exemplo.com.br])
    end

    it 'returns an empty list for an empty cell' do
      expect(convert(nil, :list)).to eq([])
      expect(convert(' ', :list)).to eq([])
    end
  end

  describe 'date' do
    it 'ignores the hour of a date cell, which is the hour the report was generated' do
      expect(convert(DateTime.new(2026, 10, 1, 23, 16, 6), :date)).to eq(Date.new(2026, 10, 1))
      expect(convert(DateTime.new(2026, 10, 1, 0, 0, 1), :date)).to eq(Date.new(2026, 10, 1))
    end

    it 'converts a text date' do
      expect(convert('29/10/2026', :date)).to eq(Date.new(2026, 10, 29))
      expect(convert('29/10/26', :date)).to eq(Date.new(2026, 10, 29))
      expect(convert('2026-10-01 09:18:04.633085', :date)).to eq(Date.new(2026, 10, 1))
      expect(convert(nil, :date)).to be_nil
    end

    it 'refuses an invalid date' do
      expect { convert('31/02/2026', :date) }.to raise_error(Atua::ConversionError)
    end
  end

  describe 'datetime' do
    it 'reads dd/mm/yy hh:mm with a two digit year in America/Sao_Paulo' do
      time = convert('01/10/26 16:45', :datetime)

      expect(time).to eq(time_zone.local(2026, 10, 1, 16, 45))
      expect(time.utc_offset).to eq(-3.hours)
    end

    it 'reads yyyy-mm-dd hh:mm:ss with or without fraction' do
      expect(convert('2026-10-01 09:18:04.633085', :datetime)).to eq(time_zone.local(2026, 10, 1, 9, 18, 4, 633_085))
      expect(convert('2026-10-01 09:18:04.6330', :datetime)).to eq(time_zone.local(2026, 10, 1, 9, 18, 4, 633_000))
      expect(convert('2015-05-25 15:41:45', :datetime)).to eq(time_zone.local(2015, 5, 25, 15, 41, 45))
    end

    it 'joins a date cell with a separate hh:mm text' do
      expect(convert(DateTime.new(2026, 10, 3, 10, 23, 57), :datetime, time: '08:31')).to eq(time_zone.local(2026, 10, 3, 8, 31))
      expect(convert(DateTime.new(2026, 10, 3, 10, 23, 57), :datetime, time: nil)).to eq(time_zone.local(2026, 10, 3))
      expect(convert(nil, :datetime, time: '08:31')).to be_nil
    end

    it 'refuses a text in an unknown format' do
      expect { convert('ontem às 10h', :datetime) }.to raise_error(Atua::ConversionError)
      expect { convert(DateTime.new(2026, 10, 3), :datetime, time: '8h31') }.to raise_error(Atua::ConversionError)
    end
  end

  describe 'yes_no' do
    let(:now) { time_zone.local(2026, 10, 13, 10, 0) }

    it 'turns no or an empty cell into nil' do
      expect(convert('Não', :yes_no, now:)).to be_nil
      expect(convert('NAO', :yes_no, now:)).to be_nil
      expect(convert(nil, :yes_no, now:)).to be_nil
    end

    it 'uses the current time for yes when there is no date' do
      expect(convert('Sim', :yes_no, now:)).to eq(now)
      expect(convert('SIM', :yes_no, now:)).to eq(now)
    end

    it 'uses the matching Atua date when it exists' do
      expect(convert('SIM', :yes_no, now:, date: DateTime.new(2020, 5, 20, 10, 38, 46))).to eq(time_zone.local(2020, 5, 20))
    end

    it 'keeps the datetime already stored on a reimport while it is still yes' do
      previous = time_zone.local(2026, 1, 5, 8, 0)

      expect(convert('Sim', :yes_no, now:, previous:)).to eq(previous)
      expect(convert('Não', :yes_no, now:, previous:)).to be_nil
    end

    it 'refuses an answer that is not yes or no' do
      expect { convert('Talvez', :yes_no, now:) }.to raise_error(Atua::ConversionError)
    end
  end

  describe 'document' do
    it 'keeps only the digits of a CNPJ or CPF' do
      expect(convert('17.469.701/0066-12', :document)).to eq('17469701006612')
      expect(convert('069.304.149/80', :document)).to eq('06930414980')
      expect(convert(nil, :document)).to be_nil
    end
  end

  describe 'plate' do
    it 'upcases and removes spaces and hyphens' do
      expect(convert(' exu-0f72 ', :plate)).to eq('EXU0F72')
      expect(convert('ABC 1234', :plate)).to eq('ABC1234')
    end
  end

  describe 'number_series' do
    it 'splits number and series with or without spaces' do
      expect(convert('74130 / 1', :number_series)).to eq([74_130, 1])
      expect(convert('74071/1', :number_series)).to eq([74_071, 1])
      expect(convert(nil, :number_series)).to eq([nil, nil])
    end

    it 'refuses a text without series' do
      expect { convert('74130', :number_series) }.to raise_error(Atua::ConversionError)
    end
  end

  describe 'state_city' do
    it 'splits the state and the city' do
      expect(convert('MG/JUIZ DE FORA', :state_city)).to eq(['MG', 'JUIZ DE FORA'])
      expect(convert('PR / FOZ DO IGUACU', :state_city)).to eq(['PR', 'FOZ DO IGUACU'])
    end
  end

  describe 'code_name' do
    it 'splits the code and the name' do
      expect(convert('802 / MAIKON RODRIGO DE LIMA', :code_name)).to eq([802, 'MAIKON RODRIGO DE LIMA'])
      expect(convert(nil, :code_name)).to eq([nil, nil])
    end
  end

  describe 'month_date' do
    it 'builds the first day of the month from month and year' do
      expect(convert('01', :month_date, year: 2024.0)).to eq(Date.new(2024, 1, 1))
      expect(convert(10.0, :month_date, year: '2024')).to eq(Date.new(2024, 10, 1))
      expect(convert(nil, :month_date, year: 2024.0)).to be_nil
    end

    it 'refuses a month out of range' do
      expect { convert('13', :month_date, year: 2024.0) }.to raise_error(Atua::ConversionError)
    end
  end

  describe 'unknown conversion' do
    it 'raises an argument error' do
      expect { convert('x', :boolean) }.to raise_error(ArgumentError, 'Conversão desconhecida boolean.')
    end
  end
end
